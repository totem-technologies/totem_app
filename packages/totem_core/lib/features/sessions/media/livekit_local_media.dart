import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/web_audio_output_router.dart';

/// [LocalMedia] backed by the LiveKit Flutter SDK.
///
/// The session controller owns one instance for its lifetime and attaches
/// each new [Room] to it. Every capture operation on the local participant
/// goes through this class, so the microphone's mute policy is decided here
/// and nowhere else.
///
/// The policy: muting disables the microphone track instead of stopping
/// capture. Stopping and reacquiring the microphone makes Android Chrome
/// switch audio modes, which leaves playback and capture quiet until the
/// page reloads. Capture stops only in [release].
///
/// LiveKit reads the policy from more than one place. `setSourceEnabled`
/// only reads the options passed to it, while server-side mutes, such as a
/// keeper muting a participant, only read the room defaults set by
/// [applyCapturePolicy]. Both must agree: a soft unmute does not restart a
/// track that a hard mute stopped.
class LiveKitLocalMedia implements LocalMedia {
  new({
    required this.cameraCaptureOptions,
    WebAudioOutputRouter? webAudioOutputRouter,
  }) : _webAudioOutputRouter = webAudioOutputRouter ?? WebAudioOutputRouter();

  /// Capture options used when this class creates a camera track.
  final CameraCaptureOptions cameraCaptureOptions;
  final WebAudioOutputRouter _webAudioOutputRouter;

  static const _microphoneCaptureOptions = AudioCaptureOptions(
    stopAudioCaptureOnMute: false,
  );

  /// Sets the room defaults that server-side mutes read. Every room the
  /// session creates must pass through this.
  static RoomOptions applyCapturePolicy(RoomOptions options) =>
      options.copyWith(defaultAudioCaptureOptions: _microphoneCaptureOptions);

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

  void attach(Room? room) {
    // Drop the reference to a released room once a different one replaces it.
    if (!identical(room, _releasedRoom)) _releasedRoom = null;
    _binding.attach(room);
    if (room == null) {
      unawaited(_webAudioOutputRouter.stop());
    } else if (supportsAudioOutputSelection) {
      unawaited(_webAudioOutputRouter.start(_binding.notify));
    }
  }

  Room? get _room => _binding.room;

  /// Capture operations run one at a time, in call order, so [release] waits
  /// for a publication still in flight. LiveKit queues its own publishes but
  /// not unpublishing.
  Future<void> _queue = Future.value();

  /// The room [release] ran for. Later capture operations on it do nothing,
  /// so a late toggle during shutdown cannot reopen capture.
  Room? _releasedRoom;

  Future<void> _serialize(
    Future<void> Function(Room room, LocalParticipant participant) operation,
  ) {
    final result = _queue.then((_) async {
      final room = _room;
      final participant = room?.localParticipant;
      if (room == null ||
          participant == null ||
          identical(room, _releasedRoom)) {
        return;
      }
      await operation(room, participant);
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

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

  LocalVideoTrack? get _activeCameraTrack {
    final publication = _participant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
    if (publication == null || !isTrackLive(publication)) return null;
    final track = publication.track;
    return track is LocalVideoTrack ? track : null;
  }

  @override
  String? get cameraDeviceId {
    final options = _participant
        ?.getTrackPublicationBySource(TrackSource.camera)
        ?.track
        ?.currentOptions;
    if (options is CameraCaptureOptions && options.deviceId != null) {
      return options.deviceId;
    }
    return _room?.roomOptions.defaultCameraCaptureOptions.deviceId;
  }

  @override
  String? get audioOutputDeviceId => kIsWeb
      ? _webAudioOutputRouter.selectedDeviceId
      : _room?.roomOptions.defaultAudioOutputOptions.deviceId;

  @override
  bool get supportsAudioOutputSelection =>
      !kIsWeb || _webAudioOutputRouter.supportsSelection;

  @override
  bool get supportsAudioOutputChooser =>
      kIsWeb && _webAudioOutputRouter.supportsOutputChooser;

  /// The facing chosen while the camera was off, applied when it turns on.
  CameraPosition? _nextCameraPosition;

  CameraPosition? get _cameraPosition {
    final options = _participant
        ?.getTrackPublicationBySource(TrackSource.camera)
        ?.track
        ?.currentOptions;
    return options is CameraCaptureOptions ? options.cameraPosition : null;
  }

  @override
  CameraFacing? get cameraFacing {
    if (_activeCameraTrack == null) return _nextCameraPosition?.toFacing();
    return _cameraPosition?.toFacing();
  }

  @override
  bool get isSpeakerOutputPreferred =>
      AudioManager.instance.isSpeakerOutputPreferred;

  @override
  Future<void> setMicrophoneEnabled(bool enabled) => _serialize(
    (_, participant) => _setMicrophoneEnabled(participant, enabled),
  );

  Future<void> _setMicrophoneEnabled(
    LocalParticipant participant,
    bool enabled,
  ) async {
    if (enabled) {
      // Something outside this class, such as the OS reclaiming the
      // microphone, may have stopped capture. A soft unmute alone would
      // leave the microphone silent.
      final track = participant
          .getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is LocalAudioTrack && !track.isActive) {
        await track.restartTrack();
      }
    }
    await participant.setMicrophoneEnabled(
      enabled,
      audioCaptureOptions: _microphoneCaptureOptions,
    );
  }

  /// Publishes the camera when joining: the [track] handed over from
  /// pre-join, or a new one from the room's default capture options, which
  /// hold the pre-join preferences.
  ///
  /// Returns false if the room was gone or already released, so nothing was
  /// published and the caller still owns [track].
  Future<bool> publishJoinCamera(
    LocalVideoTrack? track, {
    required VideoPublishOptions publishOptions,
  }) async {
    var published = false;
    await _serialize((_, participant) async {
      if (track != null) {
        await participant.publishVideoTrack(
          track,
          publishOptions: publishOptions,
        );
      } else {
        await participant.setCameraEnabled(true);
      }
      published = true;
    });
    return published;
  }

  /// Publishes the microphone when joining: the [track] handed over from
  /// pre-join, or a new one. A [muted] track is muted before publishing so
  /// it is never heard; without a pre-join track, a muted microphone is not
  /// opened at all.
  ///
  /// Returns false if the room was gone or already released, so nothing was
  /// published and the caller still owns [track].
  Future<bool> publishJoinMicrophone(
    LocalAudioTrack? track, {
    required bool muted,
  }) async {
    var published = false;
    await _serialize((_, participant) async {
      if (track == null) {
        if (!muted) await _setMicrophoneEnabled(participant, true);
      } else {
        if (muted) {
          await track.mute(
            stopOnMute: _microphoneCaptureOptions.stopAudioCaptureOnMute,
          );
        }
        await participant.publishAudioTrack(track);
      }
      published = true;
    });
    return published;
  }

  @override
  Future<void> release() => _serialize((room, participant) async {
    _releasedRoom = room;
    // Unpublishing stops each track, including a soft-muted microphone that
    // a mute would leave captured.
    await participant.unpublishAllTracks();
  });

  @override
  Future<void> setCameraEnabled(bool enabled) => _serialize((
    room,
    participant,
  ) async {
    if (enabled) {
      final position = _nextCameraPosition;
      _nextCameraPosition = null;
      await participant.setCameraEnabled(
        true,
        cameraCaptureOptions: cameraCaptureOptions.copyWith(
          deviceId: room.selectedVideoInputDeviceId,
          cameraPosition: position,
        ),
      );
      // Unmuting an existing camera keeps the facing it was captured
      // with, ignoring the options above.
      final track = _activeCameraTrack;
      if (position != null && track != null && _cameraPosition != position) {
        await track.setCameraPosition(position);
      }
    } else {
      await participant.setCameraEnabled(false);
    }
  });

  @override
  Future<void> switchCameraFacing() => _serialize((_, _) async {
    final track = _activeCameraTrack;
    if (track != null) {
      final options = track.currentOptions as CameraCaptureOptions;
      await track.setCameraPosition(options.cameraPosition.switched());
      return;
    }
    final current =
        _nextCameraPosition ??
        _cameraPosition ??
        cameraCaptureOptions.cameraPosition;
    _nextCameraPosition = current.switched();
    _binding.notify();
  });

  @override
  Future<void> selectCamera(MediaDeviceInfo device) =>
      _serialize((room, _) => room.setVideoInputDevice(device.toLiveKit()));

  @override
  Future<void> selectAudioOutput(MediaDeviceInfo device) async {
    if (kIsWeb) {
      if (!supportsAudioOutputSelection) {
        throw UnsupportedError(
          'Browser audio-output selection is unavailable.',
        );
      }
      await _webAudioOutputRouter.select(device);
      return;
    }
    // See https://github.com/livekit/client-sdk-flutter/issues/858
    await _room?.setAudioOutputDevice(device.toLiveKit());
  }

  @override
  Future<void> requestAudioOutput() async {
    if (!kIsWeb || !supportsAudioOutputChooser) {
      throw UnsupportedError('Browser audio-output selection is unavailable.');
    }
    await _webAudioOutputRouter.requestAudioOutput();
  }

  @override
  Future<void> setSpeakerOutputPreferred(bool preferred) async {
    if (kIsWeb) return;
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
  const new();

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
