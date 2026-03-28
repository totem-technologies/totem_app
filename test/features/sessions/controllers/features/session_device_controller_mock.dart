import 'package:mocktail/mocktail.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';

class MockSessionDeviceController extends Mock
    implements SessionDeviceController {}

class FakeSessionDeviceController implements SessionDeviceController {
  bool disableMicrophoneCalled = false;
  bool enableMicrophoneCalled = false;

  @override
  Future<void> disableMicrophone() async {
    disableMicrophoneCalled = true;
  }

  @override
  Future<void> enableMicrophone() async {
    enableMicrophoneCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
