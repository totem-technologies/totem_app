import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/controllers/features/session_prompts_controller.dart';

class _PromptApiClient implements ApiClient {
  new(this.onRequest);

  final Future<ApiResponse> Function(ApiRequest request) onRequest;
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) {
    requests.add(request);
    return onRequest(request);
  }

  @override
  Future<StreamedApiResponse> sendStreaming(ApiRequest request) {
    throw UnsupportedError('Streaming is not used by this test.');
  }

  @override
  Uri get baseUrl => Uri.parse('https://test.example.com');

  @override
  Future<void> close() async {}
}

ApiResponse _promptsResponse(int revision, String prompt) => ApiResponse(
  statusCode: 200,
  body: jsonEncode({
    'revision': revision,
    'prompts': [
      {
        'id': 1,
        'prompt': prompt,
        'position': 0,
        'consumed_round_numbers': <int>[],
      },
    ],
  }),
);

Future<void> _flushMicrotasks() async {
  await Future<void>.microtask(() {});
  await Future<void>.microtask(() {});
  await Future<void>.microtask(() {});
}

Future<SessionPromptsState> _runMutationFailure(int statusCode) async {
  final firstGetStarted = Completer<void>();
  var getCount = 0;
  final client = _PromptApiClient((request) {
    if (request.method == 'GET') {
      getCount++;
      if (getCount == 1) firstGetStarted.complete();
      return Future.value(_promptsResponse(getCount, 'Confirmed $getCount'));
    }
    return Future.value(ApiResponse(statusCode: statusCode, body: ''));
  });
  final container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(
        ClientApi(ApiConfig(client: client)),
      ),
    ],
  );

  final controller = container.read(
    sessionPromptsControllerProvider('test-session').notifier,
  );
  await firstGetStarted.future;
  await _flushMicrotasks();
  await controller.editPrompt(1, 'Updated');
  final state = controller.state;
  container.dispose();
  return state;
}

void main() {
  test('refresh does not overwrite an in-progress mutation', () async {
    final firstGetStarted = Completer<void>();
    final putStarted = Completer<void>();
    final putResponse = Completer<ApiResponse>();
    late _PromptApiClient client;
    var getCount = 0;
    client = _PromptApiClient((request) {
      if (request.method == 'GET') {
        getCount++;
        if (getCount == 1) {
          firstGetStarted.complete();
          return Future.value(_promptsResponse(1, 'Original'));
        }
        return Future.value(_promptsResponse(99, 'Stale refresh'));
      }

      putStarted.complete();
      return putResponse.future;
    });
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(
          ClientApi(ApiConfig(client: client)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      sessionPromptsControllerProvider('test-session').notifier,
    );
    await firstGetStarted.future;
    await _flushMicrotasks();

    final mutation = controller.editPrompt(1, 'Updated');
    await putStarted.future;
    check(controller.state.mutating).isTrue();

    await controller.refresh();

    check(getCount).equals(1);
    check(controller.state.mutating).isTrue();
    check(controller.state.revision).equals(1);
    check(controller.state.prompts.single.prompt).equals('Original');

    putResponse.complete(_promptsResponse(2, 'Updated'));
    await mutation;

    check(controller.state.mutating).isFalse();
    check(controller.state.revision).equals(2);
    check(controller.state.prompts.single.prompt).equals('Updated');
  });

  test('classifies validation API failures as validation errors', () async {
    final state = await _runMutationFailure(422);

    check(state.failure).equals(SessionPromptsFailure.validation);
    check(state.message).equals('This prompt change is not valid.');
    check(state.revision).equals(2);
    check(state.mutating).isFalse();
  });

  test('classifies server API failures as network errors', () async {
    final state = await _runMutationFailure(500);

    check(state.failure).equals(SessionPromptsFailure.network);
    check(state.message)
        .equals('Could not save prompts. Check your connection and try again.');
    check(state.revision).equals(2);
    check(state.mutating).isFalse();
  });
}
