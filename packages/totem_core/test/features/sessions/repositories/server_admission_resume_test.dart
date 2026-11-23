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
      joinOperationProvider('session'),
      (_, _) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    return container;
  }

  ApiResponse joinResponse({
    Map<String, Object?>? overrides,
    Map<String, Object?>? admissionOverrides,
  }) => ApiResponse(
    statusCode: 200,
    body: jsonEncode({
      'token': 'joined-token',
      'is_already_present': false,
      'admission': {
        'request_id': 'server-request',
        'attempt_id': 'server-attempt',
        'status': 'pending',
        'durable_state': 'none',
        'approval_required': true,
        'expires_at': '2026-01-01T00:20:00.000Z',
        'permissions': 'waiting',
        'permission_sync': 'pending',
        'revision': 1,
        'observed_at': '2026-01-01T00:00:00.000Z',
        'readiness': {'state': 'waiting_for_approval'},
        ...?admissionOverrides,
      },
      ...?overrides,
    }),
  );

  Map<String, dynamic> checkJoin(
    RecordingClient client, {
    int index = 0,
    bool fresh = false,
  }) {
    final request = client.requests[index];
    check(request.method).equals('POST');
    check(request.path).equals('/api/mobile/protected/rooms/session/join');
    final body = jsonDecode(request.body! as String) as Map<String, dynamic>;
    expect(body.keys, unorderedEquals(['operation_id', 'fresh']));
    expect(
      body['operation_id'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(body['fresh'], fresh);
    return body;
  }

  group('sessionToken canonical admission', () {
    for (final status in ['pending', 'granting', 'admitted']) {
      test(
        'accepts canonical IDs for $status without a preliminary snapshot',
        () async {
          final client = RecordingClient(
            onRequest: (_) =>
                joinResponse(admissionOverrides: {'status': status}),
          );
          final result = await containerFor(
            client,
          ).read(sessionTokenProvider('session').future);
          check(result.token).equals('joined-token');
          check(result.admission.value!.requestId).equals('server-request');
          check(result.admission.value!.attemptId).equals('server-attempt');
          check(client.requests).length.equals(1);
          checkJoin(client);
        },
      );
    }

    test(
      'uses a new operation and fresh mode for an intentional replacement',
      () async {
        final client = RecordingClient(onRequest: (_) => joinResponse());
        final container = containerFor(client);
        await container.read(sessionTokenProvider('session').future);
        container.read(joinOperationProvider('session')).reset(fresh: true);
        await container.refresh(sessionTokenProvider('session').future);
        final first = checkJoin(client);
        final second = checkJoin(client, index: 1, fresh: true);
        expect(first['operation_id'], isNot(second['operation_id']));
      },
    );

    for (final type in [
      dio.DioExceptionType.connectionError,
      dio.DioExceptionType.receiveTimeout,
    ]) {
      test('retries an uncertain $type with the same operation', () async {
        var calls = 0;
        final client = RecordingClient(
          onRequest: (_) {
            if (++calls == 1) {
              throw dio.DioException(
                requestOptions: dio.RequestOptions(path: '/join'),
                type: type,
              );
            }
            return joinResponse();
          },
        );
        final container = containerFor(client);
        await expectLater(
          container.read(sessionTokenProvider('session').future),
          throwsA(isA<AppNetworkException>()),
        );
        await container.refresh(sessionTokenProvider('session').future);
        expect(checkJoin(client), checkJoin(client, index: 1));
        check(client.requests).length.equals(2);
      });
    }

    for (final status in [404, 503]) {
      test(
        'does not fall back to a different operation on join HTTP $status',
        () async {
          final client = RecordingClient(
            onRequest: (_) => ApiResponse(
              statusCode: status,
              body: jsonEncode({'code': 'not_found', 'message': 'Unavailable'}),
            ),
          );
          await expectLater(
            containerFor(client).read(sessionTokenProvider('session').future),
            throwsA(isA<ApiError<JoinResponse, RoomErrorResponse>>()),
          );
          check(client.requests).length.equals(1);
          checkJoin(client);
        },
      );
    }

    for (final detail in [
      'invalid_attempt',
      'permanently_declined',
      'not_eligible',
    ]) {
      test('does not replace a rejected attempt: $detail', () async {
        final client = RecordingClient(
          onRequest: (_) => ApiResponse(
            statusCode: 403,
            body: jsonEncode({
              'code': 'not_joinable',
              'message': 'Rejected',
              'detail': detail,
            }),
          ),
        );
        await expectLater(
          containerFor(client).read(sessionTokenProvider('session').future),
          throwsA(isA<ApiError<JoinResponse, RoomErrorResponse>>()),
        );
        check(client.requests).length.equals(1);
        checkJoin(client);
      });
    }

    for (final admission in <Map<String, Object?>?>[
      null,
      {'permissions': 'unknown'},
      {'request_id': ''},
      {'attempt_id': ''},
      {'status': 'declined'},
      {'status': 'permanently_declined'},
      {'status': 'revoked'},
      {'status': 'cancelled'},
      {'status': 'superseded'},
      {'status': 'expired'},
      {'status': 'future_status'},
      {
        'readiness': {'state': 'future_state'},
      },
      {
        'readiness': {'state': 'blocked', 'reason': 'future_reason'},
      },
    ]) {
      test('rejects unsupported admission response $admission', () async {
        final client = RecordingClient(
          onRequest: (_) => joinResponse(
            overrides: admission == null ? {'admission': null} : null,
            admissionOverrides: admission,
          ),
        );
        await expectLater(
          containerFor(client).read(sessionTokenProvider('session').future),
          throwsStateError,
        );
        check(client.requests).length.equals(1);
        checkJoin(client);
      });
    }

    test('rejects a legacy response without admission', () async {
      final client = RecordingClient(
        onRequest: (_) => ApiResponse(
          statusCode: 200,
          body: '{"token":"legacy","is_already_present":false}',
        ),
      );
      await expectLater(
        containerFor(client).read(sessionTokenProvider('session').future),
        throwsStateError,
      );
      check(client.requests).length.equals(1);
      checkJoin(client);
    });
  });
}
