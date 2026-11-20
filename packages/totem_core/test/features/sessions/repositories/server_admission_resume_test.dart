import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:degenerate_runtime/testing.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../setup.dart';

Map<String, Object?> _snapshot(
  String status, {
  String? requestId = 'request-1',
  String? attemptId = 'attempt-1',
}) => {
  'session_slug': 'session',
  'keeper': 'keeper',
  'room_version': 1,
  'room_status': 'active',
  'approval_required': true,
  'settings_revision': 1,
  'version': 1,
  'observed_at': '2026-01-01T00:00:00.000Z',
  'admitted_count': 0,
  'activated_count': 0,
  'pending_count': 1,
  'me': {
    'identity': 'guest',
    'user': {
      'profile_avatar_type': 'boring',
      'date_created': '2026-01-01T00:00:00.000Z',
    },
    'admission_state': 'none',
    'admission_version': 1,
    'request_id': requestId,
    'attempt_id': attemptId,
    'attempt_version': 1,
    'status': status,
    'connection_state': 'connected',
    'eligible': true,
    'returning': false,
    'session_started': false,
    'late_arrival': false,
    'permission_status': 'applied',
    'permission_revision': 1,
    'applied_permission_revision': 1,
  },
};

void main() {
  setupAppConfig();

  ProviderContainer containerFor(RecordingClient client) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        apiServiceProvider.overrideWithValue(
          ClientApi(ApiConfig(client: client)),
        ),
      ],
    );
    final subscription = container.listen(
      sessionTokenProvider('session'),
      (_, _) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    return container;
  }

  ApiResponse joinResponse(
    String body, {
    Map<String, Object?>? overrides,
    Map<String, Object?>? admissionOverrides,
  }) {
    final ids = jsonDecode(body) as Map<String, dynamic>;
    return ApiResponse(
      statusCode: 200,
      body: jsonEncode({
        'token': 'joined-token',
        'is_already_present': false,
        'admission': {
          'request_id': ids['request_id'],
          'attempt_id': ids['attempt_id'],
          'status': 'pending',
          'durable_state': 'none',
          'approval_required': true,
          'expires_at': '2026-01-01T00:20:00.000Z',
          'permissions': 'waiting',
          'permission_sync': 'pending',
          'revision': 1,
          ...?admissionOverrides,
        },
        ...?overrides,
      }),
    );
  }

  RecordingClient clientFor(ApiResponse admission) => RecordingClient(
    onRequest: (request) => request.method == 'GET'
        ? admission
        : joinResponse(request.body! as String),
  );

  void checkJoin(RecordingClient client, Map<String, Object?>? expectedBody) {
    check(client.requests).length.equals(2);
    check(client.requests[0].method).equals('GET');
    check(
      client.requests[0].path,
    ).equals('/api/mobile/protected/rooms/session/admission/me');
    check(client.requests[1].method).equals('POST');
    check(
      client.requests[1].path,
    ).equals('/api/mobile/protected/rooms/session/join');
    final body =
        jsonDecode(client.requests[1].body! as String) as Map<String, dynamic>?;
    if (expectedBody == null) {
      check(body).isNotNull();
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      check(uuid.hasMatch(body!['request_id'] as String)).isTrue();
      check(uuid.hasMatch(body['attempt_id'] as String)).isTrue();
      check(body['request_id'] != body['attempt_id']).isTrue();
    } else {
      check(body).isNotNull().deepEquals(expectedBody);
    }
  }

  group('sessionToken admission resume', () {
    test('sends fresh IDs for a first-time participant', () async {
      final client = clientFor(
        ApiResponse(
          statusCode: 200,
          body: jsonEncode(_snapshot('pending')..['me'] = null),
        ),
      );
      await containerFor(client).read(sessionTokenProvider('session').future);
      checkJoin(client, null);
    });

    for (final status in ['pending', 'granting', 'approved']) {
      test('resumes the $status attempt with the snapshot IDs', () async {
        final client = clientFor(
          ApiResponse(statusCode: 200, body: jsonEncode(_snapshot(status))),
        );
        final result = await containerFor(
          client,
        ).read(sessionTokenProvider('session').future);

        check(result.token).equals('joined-token');
        checkJoin(client, {
          'request_id': 'request-1',
          'attempt_id': 'attempt-1',
        });
      });
    }

    for (final status in ['activated', 'declined', 'cancelled', 'expired']) {
      test('starts a new request after $status', () async {
        final client = clientFor(
          ApiResponse(statusCode: 200, body: jsonEncode(_snapshot(status))),
        );
        final result = await containerFor(
          client,
        ).read(sessionTokenProvider('session').future);

        check(result.token).equals('joined-token');
        checkJoin(client, null);
      });
    }

    for (final missing in ['request', 'attempt']) {
      test('fails closed when the active $missing ID is missing', () async {
        final client = clientFor(
          ApiResponse(
            statusCode: 200,
            body: jsonEncode(
              _snapshot(
                'pending',
                requestId: missing == 'request' ? null : 'request-1',
                attemptId: missing == 'attempt' ? null : 'attempt-1',
              ),
            ),
          ),
        );
        await expectLater(
          containerFor(client).read(sessionTokenProvider('session').future),
          throwsStateError,
        );
        check(client.requests).length.equals(1);
        check(client.requests.single.method).equals('GET');
      });
    }

    test('uses fresh IDs when admission endpoint returns 404', () async {
      final client = clientFor(
        ApiResponse(
          statusCode: 404,
          body: jsonEncode({'code': 'not_found', 'message': 'Not found'}),
        ),
      );
      final result = await containerFor(
        client,
      ).read(sessionTokenProvider('session').future);
      check(result.token).equals('joined-token');
      checkJoin(client, null);
    });

    test('uses fresh IDs on admission server errors', () async {
      final client = clientFor(
        ApiResponse(
          statusCode: 503,
          body: jsonEncode({'code': 'unavailable', 'message': 'Unavailable'}),
        ),
      );
      final result = await containerFor(
        client,
      ).read(sessionTokenProvider('session').future);
      check(result.token).equals('joined-token');
      checkJoin(client, null);
    });

    test('does not replace a rejected resumed attempt', () async {
      final client = RecordingClient(
        onRequest: (request) => request.method == 'GET'
            ? ApiResponse(
                statusCode: 200,
                body: jsonEncode(_snapshot('pending')),
              )
            : ApiResponse(
                statusCode: 403,
                body: jsonEncode({
                  'code': 'not_joinable',
                  'message': 'This admission attempt is no longer valid',
                  'detail': 'invalid_attempt',
                }),
              ),
      );
      await expectLater(
        containerFor(client).read(sessionTokenProvider('session').future),
        throwsA(isA<ApiError<JoinResponse, RoomErrorResponse>>()),
      );
      checkJoin(client, {'request_id': 'request-1', 'attempt_id': 'attempt-1'});
    });

    test(
      'does not replace an attempt after an uncertain join timeout',
      () async {
        final client = RecordingClient(
          onRequest: (request) => request.method == 'GET'
              ? ApiResponse(
                  statusCode: 200,
                  body: jsonEncode(_snapshot('pending')),
                )
              : throw dio.DioException(
                  requestOptions: dio.RequestOptions(path: '/join'),
                  type: dio.DioExceptionType.receiveTimeout,
                ),
        );
        await expectLater(
          containerFor(client).read(sessionTokenProvider('session').future),
          throwsA(isA<AppNetworkException>()),
        );
        checkJoin(client, {
          'request_id': 'request-1',
          'attempt_id': 'attempt-1',
        });
      },
    );

    for (final type in [
      dio.DioExceptionType.connectionError,
      dio.DioExceptionType.receiveTimeout,
    ]) {
      test('uses fresh IDs on admission $type', () async {
        final client = RecordingClient(
          onRequest: (request) => request.method == 'GET'
              ? throw dio.DioException(
                  requestOptions: dio.RequestOptions(path: '/admission/me'),
                  type: type,
                )
              : joinResponse(request.body! as String),
        );
        final result = await containerFor(
          client,
        ).read(sessionTokenProvider('session').future);
        check(result.token).equals('joined-token');
        checkJoin(client, null);
      });
    }

    test('fallback does not bypass a server join rejection', () async {
      final client = RecordingClient(
        onRequest: (request) => request.method == 'GET'
            ? ApiResponse(
                statusCode: 404,
                body: '{"code":"not_found","message":"Not found"}',
              )
            : ApiResponse(
                statusCode: 403,
                body: jsonEncode({
                  'code': 'not_joinable',
                  'message': 'Admission is permanently declined',
                  'detail': 'permanently_declined',
                }),
              ),
      );
      await expectLater(
        containerFor(client).read(sessionTokenProvider('session').future),
        throwsA(isA<ApiError<JoinResponse, RoomErrorResponse>>()),
      );
      checkJoin(client, null);
    });

    test('fallback rejects a legacy join response without admission', () async {
      final client = RecordingClient(
        onRequest: (request) => request.method == 'GET'
            ? ApiResponse(
                statusCode: 404,
                body: '{"code":"not_found","message":"Not found"}',
              )
            : ApiResponse(
                statusCode: 200,
                body: '{"token":"legacy","is_already_present":false}',
              ),
      );
      await expectLater(
        containerFor(client).read(sessionTokenProvider('session').future),
        throwsStateError,
      );
      checkJoin(client, null);
    });

    for (final admission in [
      null,
      {'permissions': 'unknown'},
      {'request_id': 'different'},
      {'status': 'declined'},
      {'status': 'permanently_declined'},
      {'status': 'revoked'},
      {'status': 'cancelled'},
      {'status': 'superseded'},
      {'status': 'expired'},
      {'status': 'future_status'},
    ]) {
      test(
        'fallback rejects unsupported admission response $admission',
        () async {
          final client = RecordingClient(
            onRequest: (request) => request.method == 'GET'
                ? ApiResponse(
                    statusCode: 404,
                    body: '{"code":"not_found","message":"Not found"}',
                  )
                : joinResponse(
                    request.body! as String,
                    overrides: admission == null ? {'admission': null} : null,
                    admissionOverrides: admission,
                  ),
          );
          await expectLater(
            containerFor(client).read(sessionTokenProvider('session').future),
            throwsStateError,
          );
          checkJoin(client, null);
        },
      );
    }
  });
}
