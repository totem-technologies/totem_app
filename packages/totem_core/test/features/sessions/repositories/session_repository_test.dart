import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../setup.dart';

class _ScriptedApiClient implements ApiClient {
  _ScriptedApiClient(List<ApiResponse Function(ApiRequest)> responders)
    : _responders = Queue<ApiResponse Function(ApiRequest)>.from(responders);

  final Queue<ApiResponse Function(ApiRequest)> _responders;
  final List<ApiRequest> requests = <ApiRequest>[];

  @override
  Uri get baseUrl => Uri.parse('https://example.com');

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (_responders.isEmpty) {
      throw StateError(
        'No scripted response available for ${request.method} ${request.path}',
      );
    }

    requests.add(request);
    return _responders.removeFirst()(request);
  }

  @override
  Future<StreamedApiResponse> sendStreaming(ApiRequest request) {
    throw UnimplementedError('Streaming is not used by these tests');
  }

  @override
  Future<void> close() async {}
}

Map<String, dynamic> _decodeJsonBody(Object? body) {
  return jsonDecode(body! as String) as Map<String, dynamic>;
}

ApiResponse _roomStateResponse(int version) {
  return ApiResponse(
    statusCode: 200,
    body: jsonEncode(<String, dynamic>{
      'session_slug': 'test-session',
      'version': version,
      'status': 'waiting_room',
      'turn_state': 'idle',
      'status_detail': <String, dynamic>{'type': 'waiting_room'},
      'current_speaker': null,
      'next_speaker': null,
      'talking_order': <String>['user-1', 'user-2'],
      'keeper': 'keeper-1',
      'banned_participants': <String>[],
      'round_number': 1,
      'round_message': null,
    }),
  );
}

ApiResponse _staleVersionResponse() {
  return ApiResponse(
    statusCode: 409,
    body: jsonEncode(<String, dynamic>{
      'code': 'stale_version',
      'message': 'State has changed since your last read',
      'detail': null,
    }),
  );
}

ApiResponse _invalidTransitionResponse() {
  return ApiResponse(
    statusCode: 400,
    body: jsonEncode(<String, dynamic>{
      'code': 'invalid_transition',
      'message': 'No stick to accept right now',
      'detail': null,
    }),
  );
}

ClientApi _createApi(_ScriptedApiClient client) {
  return ClientApi(ApiConfig(client: client));
}

void main() {
  setUpAll(() {
    setupAppConfig();
    silenceLogger();
  });

  group('session_repository stale version recovery', () {
    test('refreshes state and retries once with updated version', () async {
      final client = _ScriptedApiClient(<ApiResponse Function(ApiRequest)>[
        (request) {
          expect(request.method, 'POST');
          expect(
            request.path,
            '/api/mobile/protected/rooms/test-session/event',
          );
          final body = _decodeJsonBody(request.body);
          expect(body['last_seen_version'], 5);
          return _staleVersionResponse();
        },
        (request) {
          expect(request.method, 'GET');
          expect(
            request.path,
            '/api/mobile/protected/rooms/test-session/state',
          );
          return _roomStateResponse(10);
        },
        (request) {
          expect(request.method, 'POST');
          expect(
            request.path,
            '/api/mobile/protected/rooms/test-session/event',
          );
          final body = _decodeJsonBody(request.body);
          expect(body['last_seen_version'], 10);
          return _roomStateResponse(11);
        },
      ]);

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          apiServiceProvider.overrideWithValue(_createApi(client)),
        ],
      );
      addTearDown(container.dispose);

      final roomState = await container.read(
        passTotemProvider('test-session', 5).future,
      );

      expect(roomState.version, 11);
      expect(client.requests, hasLength(3));
    });

    test(
      'staleVersion: retries up to max attempts, throws on last failure',
      () async {
        final client = _ScriptedApiClient(<ApiResponse Function(ApiRequest)>[
          // Attempt 0
          (_) => _staleVersionResponse(),
          (_) => _roomStateResponse(10),
          // Attempt 1
          (_) => _staleVersionResponse(),
          (_) => _roomStateResponse(15),
          // Attempt 2 (last) — rethrows immediately, no GET
          (_) => _staleVersionResponse(),
        ]);

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(_createApi(client)),
          ],
        );
        addTearDown(container.dispose);

        try {
          await container.read(passTotemProvider('test-session', 5).future);
          fail('Expected passTotemProvider to throw a stale version error');
        } on ApiError<RoomState, RoomErrorResponse> catch (error) {
          expect(error.error?.code, ErrorCode.staleVersion);
        }

        // 3 POSTs + 2 GETs = 5
        expect(client.requests, hasLength(5));
      },
    );

    test(
      'staleVersion: succeeds after multiple version bumps',
      () async {
        final client = _ScriptedApiClient(<ApiResponse Function(ApiRequest)>[
          (_) => _staleVersionResponse(),
          (_) => _roomStateResponse(10),
          (_) => _staleVersionResponse(),
          (_) => _roomStateResponse(15),
          (_) => _roomStateResponse(16),
        ]);

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(_createApi(client)),
          ],
        );
        addTearDown(container.dispose);

        final roomState = await container.read(
          passTotemProvider('test-session', 5).future,
        );

        expect(roomState.version, 16);
        expect(client.requests, hasLength(5));
      },
    );

    test(
      'invalidTransition: refreshes state and retries exactly once',
      () async {
        final client = _ScriptedApiClient(<ApiResponse Function(ApiRequest)>[
          (request) {
            expect(request.method, 'POST');
            expect(
              request.path,
              '/api/mobile/protected/rooms/test-session/event',
            );
            final body = _decodeJsonBody(request.body);
            expect(body['last_seen_version'], 5);
            return _invalidTransitionResponse();
          },
          (request) {
            expect(request.method, 'GET');
            expect(
              request.path,
              '/api/mobile/protected/rooms/test-session/state',
            );
            return _roomStateResponse(6);
          },
          (request) {
            expect(request.method, 'POST');
            expect(
              request.path,
              '/api/mobile/protected/rooms/test-session/event',
            );
            final body = _decodeJsonBody(request.body);
            expect(body['last_seen_version'], 6);
            return _roomStateResponse(7);
          },
        ]);

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(_createApi(client)),
          ],
        );
        addTearDown(container.dispose);

        final roomState = await container.read(
          acceptTotemProvider('test-session', 5).future,
        );

        expect(roomState.version, 7);
        expect(client.requests, hasLength(3));
      },
    );

    test(
      'invalidTransition: surfaces error after one refresh + retry',
      () async {
        final client = _ScriptedApiClient(<ApiResponse Function(ApiRequest)>[
          (_) => _invalidTransitionResponse(),
          (_) => _roomStateResponse(6),
          (_) => _invalidTransitionResponse(),
        ]);

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(_createApi(client)),
          ],
        );
        addTearDown(container.dispose);

        try {
          await container.read(acceptTotemProvider('test-session', 5).future);
          fail('Expected acceptTotemProvider to throw');
        } on ApiError<RoomState, RoomErrorResponse> catch (error) {
          expect(error.error?.code, ErrorCode.invalidTransition);
        }

        // 1 POST + 1 GET + 1 POST = 3 (one refresh, no loop)
        expect(client.requests, hasLength(3));
      },
    );

    test(
      'does not retry on non-recoverable errors like room_not_active',
      () async {
        final client = _ScriptedApiClient(
          <ApiResponse Function(ApiRequest)>[
            (_) => ApiResponse(
              statusCode: 400,
              body: jsonEncode(<String, dynamic>{
                'code': 'room_not_active',
                'message': 'Room is not active',
                'detail': null,
              }),
            ),
          ],
        );

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(_createApi(client)),
          ],
        );
        addTearDown(container.dispose);

        try {
          await container.read(acceptTotemProvider('test-session', 5).future);
          fail('Expected acceptTotemProvider to throw');
        } on ApiError<RoomState, RoomErrorResponse> catch (error) {
          expect(error.error?.code, ErrorCode.roomNotActive);
        }

        expect(client.requests, hasLength(1));
      },
    );
  });
}
