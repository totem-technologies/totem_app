import 'dart:async';

import 'package:collection/collection.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';

/// [LocalMedia] backed by the LiveKit Flutter SDK.
///
/// The session controller owns one instance for its lifetime and attaches
/// each new [Room] to it.
class LiveKitLocalMedia implements LocalMedia {
  LiveKitLocalMedia({required this.cameraCaptureOptions});

  /// Capture options used when this class creates a camera track.
  final CameraCaptureOptions cameraCaptureOptions;

  /// Muting disables the microphone track instead of stopping capture.
  /// Stopping and reacquiring the microphone makes Android Chrome switch
  /// audio modes, which leaves playback and capture quiet until the page
  /// reloads. `setSourceEnabled` only reads this flag from the options passed
  /// to it, not from the room defaults.
  static const microphoneToggleOptions = AudioCaptureOptions(
    stopAudioCaptureOnMute: false,
  );

  final _binding = LiveKitRoomBinding(
    (listener, notify) => listener
      ..on<RoomConnectedEvent>((_) => notify())
      ..on<RoomDisconnectedEvent>((_) => notify())
      ..on<LocalTrackPublishedEvent>((_) => notify())
      ..on<LocalTrackUnpublishedEvent>((_) => notify())
      ..on<TrackMutedEvent>((event) {
        if (event.participant is LocalParticipant) notify();
      })
      ..on<TrackUnmutedEvent>((event) {
        if (event.participant is LocalParticipant) notify();
      }),
  );

  void attach(Room? room) => _binding.attach(room);

  Room? get _room => _binding.room;

  LocalParticipant? get _participant => _room?.localParticipant;

  @override
  Stream<void> get changes => _binding.changes;

  @override
  bool get isAvailable => _participant != null;

  @override
  bool get hasMicrophoneTrack =>
      _participant?.getTrackPublicationBySource(TrackSource.microphone) != null;

  @override
  bool get hasCameraTrack =>
      _participant?.getTrackPublicationBySource(TrackSource.camera) != null;

  @override
  bool get isMicrophoneEnabled => _participant?.isMicrophoneEnabled() ?? false;

  @override
  bool get isCameraEnabled {
    final publication = _participant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
    return publication != null && isTrackLive(publication);
  }

  LocalVideoTrack? get _activeCameraTrack => _participant
      ?.videoTrackPublications
      .where((t) => t.track != null && isTrackLive(t))
      .firstOrNull
      ?.track;

  @override
  String? get cameraDeviceId {
    final options = _participant?.videoTrackPublications
        .firstWhereOrNull((publication) => publication.track != null)
        ?.track
        ?.currentOptions;
    if (options is CameraCaptureOptions && options.deviceId != null) {
      return options.deviceId;
    }
    return _room?.roomOptions.defaultCameraCaptureOptions.deviceId;
  }

  @override
  String? get audioOutputDeviceId =>
      _room?.roomOptions.defaultAudioOutputOptions.deviceId;

  @override
  CameraFacing? get cameraFacing {
    final options = _activeCameraTrack?.currentOptions;
    if (options is! CameraCaptureOptions) return null;
    return options.cameraPosition.toFacing();
  }

  @override
  bool get isSpeakerOutputPreferred =>
      AudioManager.instance.isSpeakerOutputPreferred;

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _participant?.setMicrophoneEnabled(
      enabled,
      audioCaptureOptions: microphoneToggleOptions,
    );
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    final room = _room;
    final participant = _participant;
    if (room == null || participant == null) return;
    if (enabled) {
      await participant.setCameraEnabled(
        true,
        cameraCaptureOptions: cameraCaptureOptions.copyWith(
          deviceId: room.selectedVideoInputDeviceId,
        ),
      );
    } else {
      await participant.setCameraEnabled(false);
    }
  }

  @override
  Future<void> switchCameraFacing() async {
    final track = _activeCameraTrack;
    if (track != null) {
      final options = track.currentOptions as CameraCaptureOptions;
      await track.setCameraPosition(options.cameraPosition.switched());
    } else {
      await _participant?.publishVideoTrack(
        await LocalVideoTrack.createCameraTrack(cameraCaptureOptions),
      );
    }
  }

  @override
  Future<void> selectCamera(MediaDeviceInfo device) async {
    await _room?.setVideoInputDevice(device.toLiveKit());
  }

  @override
  Future<void> selectAudioOutput(MediaDeviceInfo device) async {
    // See https://github.com/livekit/client-sdk-flutter/issues/858
    await _room?.setAudioOutputDevice(device.toLiveKit());
  }

  @override
  Future<void> setSpeakerOutputPreferred(bool preferred) async {
    // LiveKit does not reliably turn the speakerphone on when it is already
    // marked preferred, so reset it first.
    unawaited(AudioManager.instance.setSpeakerOutputPreferred(false));
    if (preferred) {
      unawaited(AudioManager.instance.setSpeakerOutputPreferred(true));
    }
  }
}

/// [MediaDeviceCatalog] backed by LiveKit's [Hardware] singleton.
class LiveKitDeviceCatalog implements MediaDeviceCatalog {
  const LiveKitDeviceCatalog();

  @override
  Future<List<MediaDeviceInfo>> devices() async {
    final devices = await Hardware.instance.enumerateDevices();
    return devices.map(mediaDeviceInfoFromLiveKit).nonNulls.toList();
  }

  @override
  Stream<List<MediaDeviceInfo>> get changes =>
      Hardware.instance.onDeviceChange.stream.map(
        (devices) => devices.map(mediaDeviceInfoFromLiveKit).nonNulls.toList(),
      );
}

/// Returns null for device kinds the app does not use.
MediaDeviceInfo? mediaDeviceInfoFromLiveKit(MediaDevice device) {
  final kind = switch (device.kind) {
    'audioinput' => MediaDeviceKind.audioInput,
    'audiooutput' => MediaDeviceKind.audioOutput,
    'videoinput' => MediaDeviceKind.videoInput,
    _ => null,
  };
  if (kind == null) return null;
  return MediaDeviceInfo(
    id: device.deviceId,
    label: device.label,
    kind: kind,
    groupId: device.groupId,
  );
}

extension MediaDeviceInfoLiveKit on MediaDeviceInfo {
  MediaDevice toLiveKit() => MediaDevice(id, label, switch (kind) {
    MediaDeviceKind.audioInput => 'audioinput',
    MediaDeviceKind.audioOutput => 'audiooutput',
    MediaDeviceKind.videoInput => 'videoinput',
  }, groupId);
}

extension CameraFacingLiveKit on CameraFacing {
  CameraPosition toLiveKit() => switch (this) {
    CameraFacing.front => CameraPosition.front,
    CameraFacing.back => CameraPosition.back,
  };
}

extension CameraPositionFacing on CameraPosition {
  CameraFacing toFacing() => switch (this) {
    CameraPosition.front => CameraFacing.front,
    CameraPosition.back => CameraFacing.back,
  };
}
