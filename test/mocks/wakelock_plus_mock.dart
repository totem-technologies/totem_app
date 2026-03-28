import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setupMockWakelockPlus() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    ),
    (methodCall) async {
      return <Object?>[null]; // pigeon expects success list wrapper
    },
  );
}
