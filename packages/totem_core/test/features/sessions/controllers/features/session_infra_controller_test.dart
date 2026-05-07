import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../../../../mocks/flutter_foreground_task_mock.dart';
import '../../../../setup.dart';

class _FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WakelockPlusPlatformInterface previousWakelockPlatform;

  setUpAll(() {
    setupDotenv();

    setupMockFlutterForegroundTask();
    previousWakelockPlatform = WakelockPlusPlatformInterface.instance;
    WakelockPlusPlatformInterface.instance = _FakeWakelockPlusPlatform();
    wakelockPlusPlatformInstance = WakelockPlusPlatformInterface.instance;
  });

  tearDownAll(() {
    WakelockPlusPlatformInterface.instance = previousWakelockPlatform;
    wakelockPlusPlatformInstance = previousWakelockPlatform;
  });

  group('SessionInfraController', () {});
}
