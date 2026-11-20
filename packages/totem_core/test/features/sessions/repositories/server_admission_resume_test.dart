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

  RecordingClient clientFor(ApiResponse admission) => RecordingClient(
    onRequest: (request) => request.method == 'GET'
        ? admission
        : ApiResponse(
            statusCode: 200,
            body: jsonEncode({
              'token': 'joined-token',
              'is_already_present': false,
            }),
          ),
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
      test('does not resume when the $missing ID is missing', () async {
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
        await containerFor(client).read(sessionTokenProvider('session').future);

        checkJoin(client, null);
      });
    }

    test('fails closed when admission endpoint returns 404', () async {
      final client = clientFor(
        ApiResponse(
          statusCode: 404,
          body: jsonEncode({'code': 'not_found', 'message': 'Not found'}),
        ),
      );
      Object? caught;
      try {
        await containerFor(client).read(sessionTokenProvider('session').future);
      } catch (error) {
        caught = error;
      }
      check(caught is ApiError).isTrue();
      check((caught! as ApiError).statusCode).equals(404);
      check(client.requests).length.equals(1);
    });

    test('fails closed on non-404 admission errors', () async {
      final client = clientFor(
        ApiResponse(
          statusCode: 503,
          body: jsonEncode({'code': 'unavailable', 'message': 'Unavailable'}),
        ),
      );
      Object? caught;
      try {
        await containerFor(client).read(sessionTokenProvider('session').future);
      } catch (error) {
        caught = error;
      }

      check(caught is ApiError).isTrue();
      check((caught! as ApiError).statusCode).equals(503);
      check(client.requests).length.equals(1);
      check(client.requests.single.method).equals('GET');
    });

    test('fails closed on admission network errors', () async {
      final client = RecordingClient(
        onRequest: (_) => throw dio.DioException(
          requestOptions: dio.RequestOptions(path: '/admission/me'),
          type: dio.DioExceptionType.connectionError,
        ),
      );
      Object? caught;
      try {
        await containerFor(client).read(sessionTokenProvider('session').future);
      } catch (error) {
        caught = error;
      }

      check(caught is AppNetworkException).isTrue();
      check(client.requests).length.equals(1);
      check(client.requests.single.method).equals('GET');
    });
  });
}
