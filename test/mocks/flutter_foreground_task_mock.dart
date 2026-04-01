import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setupMockFlutterForegroundTask() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.pravera.flutter_foreground_task/methods'),
        (methodCall) async {
          if (methodCall.method == 'isRunningService') return 0;
          if (methodCall.method == 'checkNotificationPermission') {
            return 1; // granted
          }
          if (methodCall.method == 'requestIgnoreBatteryOptimization') {
            return true;
          }
          if (methodCall.method == 'startService') return 1;
          if (methodCall.method == 'stopService') return 1;
          return 1; // just return true for anything else
        },
      );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_foreground_task/methods'),
        (methodCall) async {
          if (methodCall.method == 'isRunningService') return true;
          if (methodCall.method == 'checkNotificationPermission') {
            return 1; // granted
          }
          if (methodCall.method == 'requestIgnoreBatteryOptimization') {
            return 1;
          }
          if (methodCall.method == 'startService') return 1;
          if (methodCall.method == 'stopService') return 1;
          return 1; // just return true for anything else
        },
      );
}
