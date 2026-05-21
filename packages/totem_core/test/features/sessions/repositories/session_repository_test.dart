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

ClientApi _createApi(_ScriptedApiClient client) {
  return ClientApi(ApiConfig(client: client));
}

void main() {
  setUpAll(() {
    setupDotenv();
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

    test('does not retry indefinitely when stale version persists', () async {
      final client = _ScriptedApiClient(<ApiResponse Function(ApiRequest)>[
        (_) => _staleVersionResponse(),
        (_) => _roomStateResponse(10),
        (_) => _staleVersionResponse(),
      ]);

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          apiServiceProvider.overrideWithValue(_createApi(client)),
        ],
      );
      final subscription = container.listen(
        passTotemProvider('test-session', 5),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);

      try {
        await container.read(passTotemProvider('test-session', 5).future);
        fail('Expected passTotemProvider to throw a stale version error');
      } on ApiError<RoomState, RoomErrorResponse> catch (error) {
        expect(error.error?.code, ErrorCode.staleVersion);
      }

      expect(client.requests, hasLength(3));
    });
  });
}
