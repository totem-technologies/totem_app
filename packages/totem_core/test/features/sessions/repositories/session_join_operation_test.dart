import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:degenerate_runtime/testing.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../setup.dart';

void main() {
  setupAppConfig();

  test(
    'join operations are isolated per session and reset after disposal',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = container.listen(joinOperationProvider('first'), (_, _) {});
      final second = container.listen(
        joinOperationProvider('second'),
        (_, _) {},
      );
      final firstId = first.read().id;
      final secondId = second.read().id;
      check(firstId == secondId).isFalse();
      first.close();
      await container.pump();
      final renewed = container.listen(
        joinOperationProvider('first'),
        (_, _) {},
      );
      check(renewed.read().id == firstId).isFalse();
      check(second.read().id).equals(secondId);
      renewed.close();
      second.close();
    },
  );

  test(
    'uncertain join retries the same operation and uses canonical IDs',
    () async {
      var calls = 0;
      final client = RecordingClient(
        onRequest: (request) {
          if (++calls == 1) {
            throw dio.DioException(
              requestOptions: dio.RequestOptions(path: '/join'),
              type: dio.DioExceptionType.receiveTimeout,
            );
          }
          return ApiResponse(
            statusCode: 200,
            body: jsonEncode({
              'token': 'token',
              'is_already_present': true,
              'admission': {
                'request_id': 'canonical-request',
                'attempt_id': 'canonical-attempt',
                'status': 'admitted',
                'durable_state': 'admitted',
                'approval_required': true,
                'expires_at': '2026-01-01T00:20:00.000Z',
                'permissions': 'admitted',
                'permission_sync': 'applied',
                'revision': 1,
                'observed_at': '2026-01-01T00:00:00.000Z',
                'readiness': {'state': 'activated'},
              },
            }),
          );
        },
      );
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          apiServiceProvider.overrideWithValue(
            ClientApi(ApiConfig(client: client)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        joinOperationProvider('session'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(sessionTokenProvider('session').future),
        throwsA(isA<Object>()),
      );
      final response = await container.refresh(
        sessionTokenProvider('session').future,
      );
      expect(response.admission.value!.requestId, 'canonical-request');
      expect(client.requests, hasLength(2));
      final first =
          jsonDecode(client.requests[0].body! as String)
              as Map<String, dynamic>;
      final second =
          jsonDecode(client.requests[1].body! as String)
              as Map<String, dynamic>;
      expect(first, second);
      expect(first['operation_id'], isNotEmpty);
      expect(first['fresh'], false);
      expect(first.containsKey('request_id'), false);
      expect(first.containsKey('attempt_id'), false);
      expect(
        client.requests.every((request) => request.method == 'POST'),
        true,
      );
    },
  );
}
