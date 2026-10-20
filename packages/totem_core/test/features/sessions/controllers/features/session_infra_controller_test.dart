import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/features/sessions/controllers/features/session_infra_controller.dart';

import '../../../../setup.dart';

class _FakeSessionInfraPlatform extends SessionInfraPlatform {
  new({this.canUse = true});

  final bool canUse;
  bool running = false;
  Exception? startError;
  int initializeCalls = 0;
  int startServiceCalls = 0;
  int stopServiceCalls = 0;

  @override
  bool get canUseForegroundTask => canUse;

  @override
  Future<bool> get isRunningService async => running;

  @override
  void initialize() {
    initializeCalls++;
  }

  @override
  Future<void> startService() async {
    startServiceCalls++;
    if (startError != null) throw startError!;
    running = true;
  }

  @override
  Future<void> stopService() async {
    stopServiceCalls++;
    running = false;
  }
}

void main() {
  setupAppConfig();
  silenceLogger();

  ProviderContainer createContainer(_FakeSessionInfraPlatform platform) {
    final container = ProviderContainer(
      overrides: [
        sessionInfraControllerProvider.overrideWith(
          () => SessionInfraController(platform: platform),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('desktop sessions do not start a foreground service', () async {
    final platform = _FakeSessionInfraPlatform(canUse: false);
    final controller = createContainer(platform)
        .read(sessionInfraControllerProvider.notifier);

    await controller.activate();
    await controller.deactivate();

    check(platform.initializeCalls).equals(0);
    check(platform.startServiceCalls).equals(0);
    check(platform.stopServiceCalls).equals(0);
  });

  test(
    'N5: starts the foreground service without asking for anything',
    () async {
      final platform = _FakeSessionInfraPlatform();
      final controller = createContainer(platform)
          .read(sessionInfraControllerProvider.notifier);

      await controller.activate();

      check(platform.initializeCalls).equals(1);
      check(platform.startServiceCalls).equals(1);
      check(platform.running).isTrue();
    },
  );

  test(
    'activation and deactivation are serialized around service ownership',
    () async {
      final platform = _FakeSessionInfraPlatform();
      final controller = createContainer(platform)
          .read(sessionInfraControllerProvider.notifier);

      await Future.wait([controller.activate(), controller.deactivate()]);

      check(platform.initializeCalls).equals(1);
      check(platform.startServiceCalls).equals(1);
      check(platform.stopServiceCalls).equals(1);
      check(platform.running).isFalse();
    },
  );

  test(
    'a foreground-task start failure does not break later deactivation',
    () async {
      final platform = _FakeSessionInfraPlatform()
        ..startError = Exception('boom');
      final controller = createContainer(platform)
          .read(sessionInfraControllerProvider.notifier);

      await controller.activate();
      await controller.deactivate();

      check(platform.startServiceCalls).equals(1);
      check(platform.stopServiceCalls).equals(0);
    },
  );

  test('pending activation stops before it can start after disposal', () async {
    final runningCheck = Completer<bool>();
    final delayedPlatform = _DelayedRunningCheckPlatform(runningCheck);
    final container = createContainer(delayedPlatform);
    final controller = container.read(sessionInfraControllerProvider.notifier);

    final activation = controller.activate();
    container.dispose();
    runningCheck.complete(false);
    await activation;

    check(delayedPlatform.startServiceCalls).equals(0);
  });
}

class _DelayedRunningCheckPlatform extends _FakeSessionInfraPlatform {
  new(this.completer);

  final Completer<bool> completer;

  @override
  Future<bool> get isRunningService => completer.future;
}
