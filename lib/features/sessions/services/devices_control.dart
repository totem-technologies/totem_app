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

  // TODO(bdlukaa): Revisit this in the future
  // https://github.com/livekit/client-sdk-flutter/issues/863
  // Future<void> selectCameraDevice(MediaDevice device) async {
  //   final options = CameraCaptureOptions(deviceId: device.deviceId);

  //   final userTrack = room.localParticipant
  //       ?.getTrackPublications()
  //       .firstWhereOrNull((track) => track.kind == TrackType.VIDEO)
  //       ?.track;
  //   if (userTrack != null) {
  //     userTrack.restartTrack(options);
  //   } else {
  //     await room.localParticipant?.publishVideoTrack(
  //       await LocalVideoTrack.createCameraTrack(options),
  //     );
  //   }
  //   await room.room.setVideoInputDevice(device);
  //   ref.notifyListeners();
  // }

  LocalVideoTrack? get localVideoTrack {
    final track =
        room.localParticipant?.videoTrackPublications.firstOrNull?.track;
    return track;
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
        await LocalVideoTrack.createCameraTrack(const CameraCaptureOptions()),
      );
      ref.notifyListeners();
    }
  }

  String? get selectedAudioDeviceId {
    final userTrack = room.localParticipant
        ?.getTrackPublications()
        .firstWhereOrNull((track) => track.kind == TrackType.AUDIO)
        ?.track;
    return (userTrack?.currentOptions as AudioCaptureOptions?)?.deviceId;
  }

  Future<void> selectAudioDevice(MediaDevice device) async {
    final options = AudioCaptureOptions(deviceId: device.deviceId);

    final userTrack = room.localParticipant
        ?.getTrackPublications()
        .firstWhereOrNull((track) => track.kind == TrackType.AUDIO)
        ?.track;
    if (userTrack != null) {
      userTrack.restartTrack(options);
    } else {
      await room.localParticipant?.publishAudioTrack(
        await LocalAudioTrack.create(options),
      );
    }

    await room.room.setAudioInputDevice(device);
    ref.notifyListeners();
  }

  String? get selectedAudioOutputDeviceId {
    return room.room.engine.roomOptions.defaultAudioOutputOptions.deviceId;
  }

  Future<void> selectAudioOutputDevice(MediaDevice device) async {
    await room.room.setAudioOutputDevice(device);
    ref.notifyListeners();
  }

  Future<void> enableMicrophone() async {
    if (room.microphoneOpened || hasKeeperDisconnected) {
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
        cameraCaptureOptions: CameraCaptureOptions(
          deviceId: room.room.selectedVideoInputDeviceId,
        ),
      );
    } else {
      room.localVideoTrack ??= await LocalVideoTrack.createCameraTrack(
        CameraCaptureOptions(
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
