// We need to access LivekitService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member

part of 'session_service.dart';

extension DevicesControl on Session {
  String? get selectedCameraDeviceId {
    final userTrack = room.localParticipant
        ?.getTrackPublications()
        .firstWhereOrNull((track) => track.kind == TrackType.VIDEO)
        ?.track;
    if (userTrack?.currentOptions is CameraCaptureOptions) {
      return (userTrack!.currentOptions as CameraCaptureOptions).deviceId;
    }
    return room.room.engine.roomOptions.defaultCameraCaptureOptions.deviceId;
  }

  LocalVideoTrack? get localVideoTrack {
    return room.localParticipant?.videoTrackPublications.firstOrNull?.track;
  }

  Future<void> switchCameraPosition() async {
    final track = localVideoTrack;
    if (track != null) {
      final newPosition = (track.currentOptions as CameraCaptureOptions)
          .cameraPosition
          .switched();
      track.setCameraPosition(newPosition);
      ref.notifyListeners();
      logger.i('Switched camera to $newPosition');
    } else {
      room.localParticipant?.publishVideoTrack(
        await LocalVideoTrack.createCameraTrack(Session.defaultCameraOptions),
      );
      ref.notifyListeners();
    }
  }

  LocalAudioTrack? get localAudioTrack {
    return room.localParticipant?.audioTrackPublications.firstOrNull?.track;
  }

  String? get selectedAudioDeviceId => localAudioTrack?.currentOptions.deviceId;

  Future<void> selectAudioDevice(MediaDevice device) async {
    final track = localAudioTrack;
    if (track != null) {
      track.setDeviceId(device.deviceId);
    } else {
      await room.localParticipant?.publishAudioTrack(
        await LocalAudioTrack.create(
          AudioCaptureOptions(deviceId: device.deviceId),
        ),
      );
    }

    // TODO(bdlukaa): This doesn't work on mobile.
    // See https://github.com/livekit/client-sdk-flutter/issues/959
    await room.room.setAudioInputDevice(device);
    ref.notifyListeners();
  }

  String? get selectedAudioOutputDeviceId {
    return room.room.engine.roomOptions.defaultAudioOutputOptions.deviceId;
  }

  Future<void> selectAudioOutputDevice(MediaDevice device) async {
    // TODO(bdlukaa): This doesn't work on mobile.
    // See https://github.com/livekit/client-sdk-flutter/issues/858
    await room.room.setAudioOutputDevice(device);
    ref.notifyListeners();
  }

  Future<void> enableMicrophone() async {
    // workaround to use members on extension
    // ignore: invalid_use_of_visible_for_testing_member
    if (room.microphoneOpened || state.hasKeeperDisconnected) {
      return;
    }
    if (room.localParticipant != null) {
      await room.localParticipant?.setMicrophoneEnabled(true);
    } else {
      room.localAudioTrack ??= await LocalAudioTrack.create(
        AudioCaptureOptions(deviceId: room.room.selectedAudioInputDeviceId),
      );
    }
    ref.notifyListeners();
  }

  Future<void> disableMicrophone() async {
    if (!room.microphoneOpened) {
      return;
    }
    if (room.connected) {
      await room.localParticipant?.setMicrophoneEnabled(false);
    } else {
      await room.localAudioTrack?.dispose();
      room.localAudioTrack = null;
    }
    ref.notifyListeners();
  }

  Future<void> enableCamera() async {
    if (room.cameraOpened) {
      return;
    }
    if (room.connected) {
      await room.localParticipant?.setCameraEnabled(
        true,
        cameraCaptureOptions: Session.defaultCameraOptions.copyWith(
          deviceId: room.room.selectedVideoInputDeviceId,
        ),
      );
    } else {
      room.localVideoTrack ??= await LocalVideoTrack.createCameraTrack(
        Session.defaultCameraOptions.copyWith(
          deviceId: room.room.selectedVideoInputDeviceId,
        ),
      );
    }

    ref.notifyListeners();
  }

  Future<void> disableCamera() async {
    if (!room.cameraOpened) {
      return;
    }
    if (room.connected) {
      await room.localParticipant?.setCameraEnabled(false);
    } else {
      await room.localVideoTrack?.dispose();
      room.localVideoTrack = null;
    }
    ref.notifyListeners();
  }
}
