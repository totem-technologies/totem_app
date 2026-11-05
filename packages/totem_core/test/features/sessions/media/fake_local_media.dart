import 'dart:async';

import 'package:totem_core/features/permissions/model.dart';
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
    this.supportsAudioOutputSelection = true,
    this.supportsAudioOutputChooser = false,
    this.isSpeakerOutputPreferred = true,
  });

  final _changes = StreamController<void>.broadcast(sync: true);
  final _captureLost = StreamController<CaptureLost>.broadcast(sync: true);

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
  bool supportsAudioOutputSelection;
  @override
  bool supportsAudioOutputChooser;
  @override
  CameraFacing? cameraFacing;
  @override
  bool isSpeakerOutputPreferred;

  /// Runs before a camera command applies, so tests can hold a command in
  /// flight or make it fail by throwing.
  Future<void> Function(bool enabled)? onCameraCommand;

  /// Runs before a microphone command applies, so tests can make it fail.
  Future<void> Function(bool enabled)? onMicrophoneCommand;

  /// Runs before a camera switch applies, so tests can make it fail.
  Future<void> Function()? onCameraSwitch;

  /// Runs before a speaker route applies, so tests can hold it in flight.
  Future<void> Function(bool preferred)? onSpeakerOutputCommand;

  /// False drops device commands without an error, as the real media does
  /// once its room is released.
  bool appliesCommands = true;

  final List<bool> microphoneCommands = [];
  int releaseCount = 0;
  final List<bool> cameraCommands = [];
  final List<bool> speakerOutputCommands = [];

  /// Simulates a change made outside the app, such as a keeper muting the
  /// participant.
  void emitChange() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<CaptureLost> get captureLost => _captureLost.stream;

  /// Simulates capture stopping outside the app, such as a revoked
  /// permission. Like the real media, the device ends up off.
  void loseCapture(MediaKind kind) {
    final wasOn = switch (kind) {
      MediaKind.camera => isCameraEnabled,
      MediaKind.microphone => isMicrophoneEnabled,
    };
    switch (kind) {
      case MediaKind.camera:
        isCameraEnabled = false;
      case MediaKind.microphone:
        isMicrophoneEnabled = false;
    }
    _captureLost.add(CaptureLost(kind, wasOn: wasOn));
    emitChange();
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    microphoneCommands.add(enabled);
    await onMicrophoneCommand?.call(enabled);
    if (!appliesCommands) return;
    hasMicrophoneTrack = true;
    isMicrophoneEnabled = enabled;
    emitChange();
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraCommands.add(enabled);
    await onCameraCommand?.call(enabled);
    if (!appliesCommands) return;
    hasCameraTrack = true;
    isCameraEnabled = enabled;
    cameraFacing = enabled ? (cameraFacing ?? CameraFacing.front) : null;
    emitChange();
  }

  @override
  Future<void> setCameraFacing(CameraFacing facing) async {
    cameraFacing = facing;
    emitChange();
  }

  @override
  Future<void> switchCameraFacing() async {
    await onCameraSwitch?.call();
    // Like the real media, a camera that's off only remembers the facing
    // to start with.
    cameraFacing = cameraFacing?.switched ?? CameraFacing.back;
    emitChange();
  }

  @override
  Future<void> selectCamera(MediaDeviceInfo device) async {
    await onCameraSwitch?.call();
    cameraDeviceId = device.id;
    emitChange();
  }

  @override
  Future<void> selectAudioOutput(MediaDeviceInfo device) async {
    audioOutputDeviceId = device.id;
    emitChange();
  }

  @override
  Future<void> requestAudioOutput() async {}

  @override
  Future<void> release() async {
    releaseCount++;
    hasMicrophoneTrack = false;
    isMicrophoneEnabled = false;
    hasCameraTrack = false;
    isCameraEnabled = false;
    cameraFacing = null;
    emitChange();
  }

  @override
  Future<void> setSpeakerOutputPreferred(bool preferred) async {
    speakerOutputCommands.add(preferred);
    await onSpeakerOutputCommand?.call(preferred);
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
