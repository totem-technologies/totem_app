// We need to access LivekitService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member

part of 'session_service.dart';

extension DevicesControl on Session {
  String? get selectedCameraDeviceId {
    final userTrack = context.localParticipant
        ?.getTrackPublications()
        .firstWhereOrNull((track) => track.kind == TrackType.VIDEO)
        ?.track;
    if (userTrack?.currentOptions is CameraCaptureOptions) {
      return (userTrack!.currentOptions as CameraCaptureOptions).deviceId;
    }
    return context.room.engine.roomOptions.defaultCameraCaptureOptions.deviceId;
  }

  LocalVideoTrack? get localVideoTrack {
    return context.localParticipant?.videoTrackPublications.firstOrNull?.track;
  }

  Future<void> switchCameraPosition() async {
    try {
      final track = localVideoTrack;
      if (track != null) {
        final newPosition = (track.currentOptions as CameraCaptureOptions)
            .cameraPosition
            .switched();
        track.setCameraPosition(newPosition);
        ref.notifyListeners();
        logger.i('Switched camera to $newPosition');
      } else {
        context.localParticipant?.publishVideoTrack(
          await LocalVideoTrack.createCameraTrack(Session.defaultCameraOptions),
        );
        ref.notifyListeners();
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to switch camera position',
      );
    }
  }

  LocalAudioTrack? get localAudioTrack {
    return context.localParticipant?.audioTrackPublications.firstOrNull?.track;
  }

  String? get selectedAudioDeviceId => localAudioTrack?.currentOptions.deviceId;

  Future<void> selectAudioDevice(MediaDevice device) async {
    final track = localAudioTrack;
    if (track != null) {
      track.setDeviceId(device.deviceId);
    } else {
      await context.localParticipant?.publishAudioTrack(
        await LocalAudioTrack.create(
          AudioCaptureOptions(deviceId: device.deviceId),
        ),
      );
    }

    // TODO(bdlukaa): This doesn't work on mobile.
    // See https://github.com/livekit/client-sdk-flutter/issues/959
    await context.room.setAudioInputDevice(device);
    ref.notifyListeners();
  }

  String? get selectedAudioOutputDeviceId {
    return context.room.engine.roomOptions.defaultAudioOutputOptions.deviceId;
  }

  Future<void> selectAudioOutputDevice(MediaDevice device) async {
    // TODO(bdlukaa): This doesn't work on mobile.
    // See https://github.com/livekit/client-sdk-flutter/issues/858
    await context.room.setAudioOutputDevice(device);
    ref.notifyListeners();
  }

  Future<void> enableMicrophone() async {
    if (context.microphoneOpened) return;

    if (context.localParticipant != null) {
      await context.localParticipant?.setMicrophoneEnabled(true);
    } else {
      context.localAudioTrack ??= await LocalAudioTrack.create(
        AudioCaptureOptions(deviceId: context.room.selectedAudioInputDeviceId),
      );
    }
    ref.notifyListeners();
  }

  Future<void> disableMicrophone() async {
    if (!context.microphoneOpened) {
      return;
    }
    if (context.connected) {
      await context.localParticipant?.setMicrophoneEnabled(false);
    } else {
      await context.localAudioTrack?.dispose();
      context.localAudioTrack = null;
    }
    ref.notifyListeners();
  }

  Future<void> enableCamera() async {
    if (context.cameraOpened) {
      return;
    }
    if (context.connected) {
      await context.localParticipant?.setCameraEnabled(
        true,
        cameraCaptureOptions: Session.defaultCameraOptions.copyWith(
          deviceId: context.room.selectedVideoInputDeviceId,
        ),
      );
    } else {
      context.localVideoTrack ??= await LocalVideoTrack.createCameraTrack(
        Session.defaultCameraOptions.copyWith(
          deviceId: context.room.selectedVideoInputDeviceId,
        ),
      );
    }

    ref.notifyListeners();
  }

  Future<void> disableCamera() async {
    if (!context.cameraOpened) {
      return;
    }
    if (context.connected) {
      await context.localParticipant?.setCameraEnabled(false);
    } else {
      await context.localVideoTrack?.dispose();
      context.localVideoTrack = null;
    }
    ref.notifyListeners();
  }
}
