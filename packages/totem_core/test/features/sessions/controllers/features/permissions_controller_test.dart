import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:totem_app/features/sessions/controllers/features/permissions_controller.dart';

import '../../../../setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupDotenv();
  silenceLogger();

  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  const foregroundTaskChannel = MethodChannel(
    'flutter_foreground_task/methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'checkPermissionStatus') {
            return 1;
          }

          if (methodCall.method == 'shouldShowRequestPermissionRationale') {
            return false;
          }

          if (methodCall.method == 'openAppSettings') {
            return false;
          }

          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundTaskChannel, (methodCall) async {
          if (methodCall.method == 'checkNotificationPermission') {
            return 1;
          }

          if (methodCall.method == 'requestNotificationPermission') {
            return 0;
          }

          if (methodCall.method == 'isRunningService') {
            return false;
          }

          if (methodCall.method == 'requestIgnoreBatteryOptimization') {
            return true;
          }

          return 1;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundTaskChannel, null);
  });

  test('requestPermissions updates the state while mounted', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(permissionsControllerProvider.future);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'requestPermissions') {
            final requested = List<int>.from(methodCall.arguments as List);
            return {
              for (final permission in requested) permission: 1,
            };
          }

          if (methodCall.method == 'checkPermissionStatus') {
            return 1;
          }

          if (methodCall.method == 'shouldShowRequestPermissionRationale') {
            return false;
          }

          if (methodCall.method == 'openAppSettings') {
            return false;
          }

          return null;
        });

    await container
        .read(permissionsControllerProvider.notifier)
        .requestPermissions();

    final permissions = container.read(permissionsControllerProvider);
    expect(permissions.asData?.value.cameraStatus, PermissionStatus.granted);
    expect(
      permissions.asData?.value.microphoneStatus,
      PermissionStatus.granted,
    );
    expect(
      permissions.asData?.value.notificationStatus,
      PermissionStatus.granted,
    );
  });

  test(
    'requestPermissions completes after disposal without throwing',
    () async {
      final requestCompleter = Completer<Map<int, int>>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'requestPermissions') {
              return requestCompleter.future;
            }

            if (methodCall.method == 'checkPermissionStatus') {
              return 1;
            }

            if (methodCall.method == 'shouldShowRequestPermissionRationale') {
              return false;
            }

            if (methodCall.method == 'openAppSettings') {
              return false;
            }

            return null;
          });

      final container = ProviderContainer();
      final subscription = container.listen(
        permissionsControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);

      await container.read(permissionsControllerProvider.future);

      final future = container
          .read(permissionsControllerProvider.notifier)
          .requestPermissions();

      container.dispose();

      requestCompleter.complete({
        Permission.camera.value: 1,
        Permission.microphone.value: 1,
        Permission.notification.value: 1,
      });

      await expectLater(future, completes);
    },
  );
}
