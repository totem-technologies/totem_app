import 'dart:async';

import 'package:totem_core/features/sessions/media/local_media.dart';

/// In-memory [LocalMedia] whose commands update its own state, like a real
/// backend would after the SDK applies them.
class FakeLocalMedia implements LocalMedia {
  FakeLocalMedia({
    this.isAvailable = true,
    this.hasMicrophoneTrack = false,
    this.hasCameraTrack = false,
    this.isMicrophoneEnabled = false,
    this.isCameraEnabled = false,
    this.cameraDeviceId,
    this.audioOutputDeviceId,
    this.cameraFacing,
    this.isSpeakerOutputPreferred = true,
  });

  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  bool isAvailable;
  @override
  bool hasMicrophoneTrack;
  @override
  bool hasCameraTrack;
  @override
  bool isMicrophoneEnabled;
  @override
  bool isCameraEnabled;
  @override
  String? cameraDeviceId;
  @override
  String? audioOutputDeviceId;
  @override
  CameraFacing? cameraFacing;
  @override
  bool isSpeakerOutputPreferred;

  /// Runs before a camera command applies, so tests can hold a command in
  /// flight or make it fail by throwing.
  Future<void> Function(bool enabled)? onCameraCommand;

  final List<bool> microphoneCommands = [];
  final List<bool> cameraCommands = [];

  /// Simulates a change made outside the app, such as a keeper muting the
  /// participant.
  void emitChange() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    microphoneCommands.add(enabled);
    hasMicrophoneTrack = true;
    isMicrophoneEnabled = enabled;
    emitChange();
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraCommands.add(enabled);
    await onCameraCommand?.call(enabled);
    hasCameraTrack = true;
    isCameraEnabled = enabled;
    cameraFacing = enabled ? (cameraFacing ?? CameraFacing.front) : null;
    emitChange();
  }

  @override
  Future<void> switchCameraFacing() async {
    cameraFacing = cameraFacing?.switched ?? CameraFacing.front;
    hasCameraTrack = true;
    isCameraEnabled = true;
    emitChange();
  }

  @override
  Future<void> selectCamera(MediaDeviceInfo device) async {
    cameraDeviceId = device.id;
    emitChange();
  }

  @override
  Future<void> selectAudioOutput(MediaDeviceInfo device) async {
    audioOutputDeviceId = device.id;
    emitChange();
  }

  @override
  Future<void> setSpeakerOutputPreferred(bool preferred) async {
    isSpeakerOutputPreferred = preferred;
  }
}

class FakeMediaDeviceCatalog implements MediaDeviceCatalog {
  FakeMediaDeviceCatalog([this.current = const []]);

  List<MediaDeviceInfo> current;
  final _changes = StreamController<List<MediaDeviceInfo>>.broadcast();

  void replaceDevices(List<MediaDeviceInfo> devices) {
    current = devices;
    _changes.add(devices);
  }

  @override
  Future<List<MediaDeviceInfo>> devices() async => current;

  @override
  Stream<List<MediaDeviceInfo>> get changes => _changes.stream;
}

MediaDeviceInfo fakeCamera(String id, [String label = '']) =>
    MediaDeviceInfo(id: id, label: label, kind: MediaDeviceKind.videoInput);

MediaDeviceInfo fakeAudioOutput(String id, [String label = '']) =>
    MediaDeviceInfo(id: id, label: label, kind: MediaDeviceKind.audioOutput);
