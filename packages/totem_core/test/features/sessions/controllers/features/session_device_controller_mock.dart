import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';

class MockSessionDeviceController extends Mock
    implements SessionDeviceController {
  /// No device stops unless a test supplies a stream.
  Stream<MediaKind> deviceNeedsAttentionStream = const Stream.empty();

  @override
  Stream<MediaKind> get deviceNeedsAttention => deviceNeedsAttentionStream;

  Stream<(MediaKind, TurnOnBlocker)> turnOnBlockedStream = const Stream.empty();

  @override
  Stream<(MediaKind, TurnOnBlocker)> get turnOnBlocked => turnOnBlockedStream;

  @override
  MediaControl control(MediaKind kind) => _controlFor(this, kind);
}

class FakeSessionDeviceController implements SessionDeviceController {
  bool disableMicrophoneCalled = false;
  bool disableCameraCalled = false;
  bool _cameraEnabled = false;

  /// Devices passed to [turnOn], in order.
  final turnedOn = <MediaKind>[];

  /// Whether the microphone comes on when turned on.
  bool microphoneStarts = true;

  /// Whether the microphone is on.
  bool microphoneOn = true;

  /// Devices flagged with [flagNeedsAttention].
  final flagged = <MediaKind>[];

  @override
  Future<void> disableMicrophone() async {
    disableMicrophoneCalled = true;
  }

  @override
  bool get isMicrophoneEnabled => microphoneOn;

  @override
  void flagNeedsAttention(MediaKind kind) => flagged.add(kind);

  @override
  String get selectedCameraDeviceId => 'camera-1';

  @override
  bool get isCameraEnabled => _cameraEnabled;

  @override
  Future<TurnOnOutcome> turnOn(MediaKind kind) async {
    turnedOn.add(kind);
    switch (kind) {
      case MediaKind.camera:
        _cameraEnabled = true;
      case MediaKind.microphone:
        microphoneOn = microphoneStarts;
        if (!microphoneStarts) {
          return const TurnOnFailed(DeviceFailed(DeviceProblem.failed));
        }
    }
    return const TurnedOn();
  }

  @override
  Future<void> disableCamera() async {
    disableCameraCalled = true;
    _cameraEnabled = false;
  }

  @override
  Stream<MediaKind> get deviceNeedsAttention => const Stream.empty();

  @override
  Stream<(MediaKind, TurnOnBlocker)> get turnOnBlocked => const Stream.empty();

  @override
  MediaControl control(MediaKind kind) => _controlFor(this, kind);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A control that turns devices on the way production does, through
/// [SessionDeviceController.turnOn].
MediaControl _controlFor(SessionDeviceController devices, MediaKind kind) =>
    MediaControl(
      kind: kind,
      problem: Provider<DeviceProblem?>((_) => null),
      turnOn: () => devices.turnOn(kind),
    );
