// Uses the generated client's existing transitive test adapter without adding a
// test-only dependency solely for repository boundary tests.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:degenerate_runtime/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../setup.dart';

const _slug = 'rva183exo';

ProviderContainer _container(RecordingClient client) {
  final container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(
        ClientApi(ApiConfig(client: client)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setupAppConfig();

  group('sessionToken', () {
    test('retries a failed join request before giving up', () async {
      var requests = 0;
      final client = RecordingClient(
        onRequest: (_) {
          requests++;
          return requests == 1
              ? ApiResponse(statusCode: 503, body: 'unavailable')
              : ApiResponse(
                  statusCode: 200,
                  body: jsonEncode({
                    'token': 'livekit-token',
                    'is_already_present': false,
                  }),
                );
        },
      );

      final response = await _container(
        client,
      ).read(sessionTokenProvider(_slug).future);

      check(response.token).equals('livekit-token');
      check(requests).equals(2);
    });

    test('does not retry when the session is not joinable', () async {
      var requests = 0;
      final client = RecordingClient(
        onRequest: (_) {
          requests++;
          return ApiResponse(
            statusCode: 403,
            body: jsonEncode({
              'code': 'not_joinable',
              'message': 'Session is not joinable at this time',
            }),
          );
        },
      );

      await check(
        _container(client).read(sessionTokenProvider(_slug).future),
      ).throws<Object>();
      check(requests).equals(1);
    });
  });
}
