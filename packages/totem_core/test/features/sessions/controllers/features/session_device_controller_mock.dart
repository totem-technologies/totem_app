import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';

class MockSessionDeviceController extends Mock
    implements SessionDeviceController {}

class FakeSessionDeviceController implements SessionDeviceController {
  bool enableMicrophoneCalled = false;
  bool disableMicrophoneCalled = false;

  bool enableCameraCalled = false;
  bool disableCameraCalled = false;

  @override
  Future<void> disableMicrophone() async {
    disableMicrophoneCalled = true;
  }

  @override
  Future<void> enableMicrophone() async {
    enableMicrophoneCalled = true;
  }

  @override
  bool get isMicrophoneEnabled => true;

  @override
  String get selectedCameraDeviceId => 'camera-1';

  @override
  Future<void> enableCamera() async {
    enableCameraCalled = true;
  }

  @override
  Future<void> disableCamera() async {
    disableCameraCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
