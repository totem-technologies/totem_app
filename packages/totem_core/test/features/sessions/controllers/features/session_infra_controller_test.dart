import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/features/sessions/controllers/features/session_infra_controller.dart';

import '../../../../setup.dart';

class _FakeSessionInfraPlatform extends SessionInfraPlatform {
  _FakeSessionInfraPlatform({
    this.canUse = true,
    this.android = false,
    this.notificationPermission = NotificationPermission.granted,
    this.requestedNotificationPermission = NotificationPermission.granted,
    this.ignoringBatteryOptimizations = true,
    this.ignoreBatteryOptimizationResult = true,
  });

  final bool canUse;
  final bool android;
  NotificationPermission notificationPermission;
  final NotificationPermission requestedNotificationPermission;
  bool running = false;
  final bool ignoringBatteryOptimizations;
  final bool ignoreBatteryOptimizationResult;
  Exception? startError;
  int initializeCalls = 0;
  int requestNotificationPermissionCalls = 0;
  int requestIgnoreBatteryOptimizationCalls = 0;
  int startServiceCalls = 0;
  int stopServiceCalls = 0;

  @override
  bool get canUseForegroundTask => canUse;

  @override
  bool get isAndroid => android;

  @override
  Future<NotificationPermission> checkNotificationPermission() async =>
      notificationPermission;

  @override
  Future<NotificationPermission> requestNotificationPermission() async {
    requestNotificationPermissionCalls++;
    return notificationPermission = requestedNotificationPermission;
  }

  @override
  Future<bool> get isIgnoringBatteryOptimizations async =>
      ignoringBatteryOptimizations;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async {
    requestIgnoreBatteryOptimizationCalls++;
    return ignoreBatteryOptimizationResult;
  }

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

  test(
    'desktop sessions do not request native foreground-task permissions',
    () async {
      final platform = _FakeSessionInfraPlatform(canUse: false);
      final controller = createContainer(
        platform,
      ).read(sessionInfraControllerProvider.notifier);

      check(await controller.requestPermissions()).isTrue();
      await controller.activate();
      await controller.deactivate();

      check(platform.initializeCalls).equals(0);
      check(platform.startServiceCalls).equals(0);
      check(platform.stopServiceCalls).equals(0);
    },
  );

  test('permission denial prevents foreground service activation', () async {
    final platform = _FakeSessionInfraPlatform(
      notificationPermission: NotificationPermission.denied,
      requestedNotificationPermission: NotificationPermission.denied,
    );
    final controller = createContainer(
      platform,
    ).read(sessionInfraControllerProvider.notifier);

    await controller.activate();

    check(platform.requestNotificationPermissionCalls).equals(1);
    check(platform.initializeCalls).equals(0);
    check(platform.startServiceCalls).equals(0);
  });

  test(
    'Android battery optimization is requested after notification access',
    () async {
      final platform = _FakeSessionInfraPlatform(
        android: true,
        ignoringBatteryOptimizations: false,
        ignoreBatteryOptimizationResult: true,
      );
      final controller = createContainer(
        platform,
      ).read(sessionInfraControllerProvider.notifier);

      check(await controller.requestPermissions()).isTrue();

      check(platform.requestIgnoreBatteryOptimizationCalls).equals(1);
    },
  );

  test(
    'activation and deactivation are serialized around service ownership',
    () async {
      final platform = _FakeSessionInfraPlatform();
      final controller = createContainer(
        platform,
      ).read(sessionInfraControllerProvider.notifier);

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
      final controller = createContainer(
        platform,
      ).read(sessionInfraControllerProvider.notifier);

      await controller.activate();
      await controller.deactivate();

      check(platform.startServiceCalls).equals(1);
      check(platform.stopServiceCalls).equals(0);
    },
  );

  test('pending activation stops before it can start after disposal', () async {
    final permissionRequest = Completer<NotificationPermission>();
    final platform = _FakeSessionInfraPlatform();
    final originalRequest = platform.requestedNotificationPermission;
    // Keep the platform fake deterministic while delaying the permission edge.
    final delayedPlatform = _DelayedPermissionPlatform(
      platform,
      permissionRequest,
      originalRequest,
    );
    final container = createContainer(delayedPlatform);
    final controller = container.read(sessionInfraControllerProvider.notifier);

    final activation = controller.activate();
    container.dispose();
    permissionRequest.complete(NotificationPermission.granted);
    await activation;

    check(delayedPlatform.initializeCalls).equals(0);
    check(delayedPlatform.startServiceCalls).equals(0);
  });
}

class _DelayedPermissionPlatform extends _FakeSessionInfraPlatform {
  _DelayedPermissionPlatform(
    this.delegate,
    this.completer,
    NotificationPermission requested,
  ) : super(requestedNotificationPermission: requested);

  final _FakeSessionInfraPlatform delegate;
  final Completer<NotificationPermission> completer;

  @override
  bool get canUseForegroundTask => delegate.canUseForegroundTask;

  @override
  bool get isAndroid => delegate.isAndroid;

  @override
  Future<NotificationPermission> checkNotificationPermission() =>
      delegate.checkNotificationPermission();

  @override
  Future<NotificationPermission> requestNotificationPermission() async {
    final permission = await completer.future;
    delegate.notificationPermission = permission;
    return permission;
  }

  @override
  Future<bool> get isIgnoringBatteryOptimizations =>
      delegate.isIgnoringBatteryOptimizations;

  @override
  Future<bool> requestIgnoreBatteryOptimization() =>
      delegate.requestIgnoreBatteryOptimization();

  @override
  Future<bool> get isRunningService => delegate.isRunningService;

  @override
  void initialize() => delegate.initialize();

  @override
  Future<void> startService() => delegate.startService();

  @override
  Future<void> stopService() => delegate.stopService();

  @override
  int get initializeCalls => delegate.initializeCalls;

  @override
  int get startServiceCalls => delegate.startServiceCalls;
}
