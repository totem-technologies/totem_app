import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The foreground service channels, answering as if the service starts and
/// stops normally. Sessions only start, update and stop the service.
void setupMockFlutterForegroundTask() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.pravera.flutter_foreground_task/methods'),
        (methodCall) async {
          if (methodCall.method == 'isRunningService') return 0;
          return 1;
        },
      );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_foreground_task/methods'),
        (methodCall) async {
          if (methodCall.method == 'isRunningService') return true;
          return 1;
        },
      );
}

void clearMockFlutterForegroundTask() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.pravera.flutter_foreground_task/methods'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_foreground_task/methods'),
        null,
      );
}
