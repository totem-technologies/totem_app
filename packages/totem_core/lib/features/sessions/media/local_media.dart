import 'package:flutter/foundation.dart';

/// App-owned boundary between session code and the media SDK.
///
/// Controllers and widgets use these types instead of SDK classes so the media
/// backend can differ per platform (for example, the LiveKit JS SDK on web)
/// without changing session logic, and so tests can use plain fakes.

enum MediaDeviceKind { audioInput, audioOutput, videoInput }

@immutable
class MediaDeviceInfo {
  const MediaDeviceInfo({
    required this.id,
    required this.label,
    required this.kind,
    this.groupId,
  });

  final String id;

  /// The label reported by the platform. Browsers report an empty label until
  /// the user grants media permission.
  final String label;
  final MediaDeviceKind kind;
  final String? groupId;

  String get displayLabel {
    if (label.isNotEmpty) return label;
    return switch (kind) {
      MediaDeviceKind.audioInput => 'Microphone',
      MediaDeviceKind.audioOutput => 'Speaker',
      MediaDeviceKind.videoInput => 'Camera',
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaDeviceInfo &&
        other.id == id &&
        other.label == label &&
        other.kind == kind &&
        other.groupId == groupId;
  }

  @override
  int get hashCode => Object.hash(id, label, kind, groupId);

  @override
  String toString() => 'MediaDeviceInfo($kind, $id, $label)';
}

enum CameraFacing {
  front,
  back;

  CameraFacing get switched => switch (this) {
    CameraFacing.front => CameraFacing.back,
    CameraFacing.back => CameraFacing.front,
  };
}

/// Lists the capture and playback devices. Usable before joining a room.
abstract interface class MediaDeviceCatalog {
  Future<List<MediaDeviceInfo>> devices();

  /// Emits the full device list whenever a device is added or removed.
  Stream<List<MediaDeviceInfo>> get changes;
}

/// The local participant's microphone, camera and audio output in a room.
abstract interface class LocalMedia {
  /// Emits whenever any getter below may have changed, including changes made
  /// outside this interface, such as a keeper muting the participant.
  Stream<void> get changes;

  /// Whether a room is attached that local media can be published to.
  bool get isAvailable;

  /// Whether a microphone or camera track is published, muted or not. Before
  /// that, callers fall back to the user's join preferences.
  bool get hasMicrophoneTrack;
  bool get hasCameraTrack;

  bool get isMicrophoneEnabled;
  bool get isCameraEnabled;

  String? get cameraDeviceId;
  String? get audioOutputDeviceId;

  /// The facing of the active camera, or null while the camera is off.
  CameraFacing? get cameraFacing;

  /// Mobile only: whether audio should play through the loudspeaker rather
  /// than the earpiece when no external output is connected.
  bool get isSpeakerOutputPreferred;

  /// Muting keeps the microphone captured and only stops sending audio.
  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  /// Flips the active camera, or publishes the front camera if none is active.
  Future<void> switchCameraFacing();

  Future<void> selectCamera(MediaDeviceInfo device);
  Future<void> selectAudioOutput(MediaDeviceInfo device);

  Future<void> setSpeakerOutputPreferred(bool preferred);
}
