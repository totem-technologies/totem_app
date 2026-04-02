import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setupMockPermissionHandler() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (methodCall) async {
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
        },
      );
}

void clearMockPermissionHandler() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        null,
      );
}
