// We need to access LivekitService.ref to notify listeners
// ignore_for_file: invalid_use_of_visible_for_testing_member, experimental_member_use, invalid_use_of_protected_member

part of 'session_service.dart';

extension DevicesControl on Session {
  static const externalAudioOutputTypes = <audio.AudioDeviceType>{
    audio.AudioDeviceType.wiredHeadset,
    audio.AudioDeviceType.wiredHeadphones,
    audio.AudioDeviceType.bluetoothSco,
    audio.AudioDeviceType.bluetoothA2dp,
    audio.AudioDeviceType.bluetoothLe,
    audio.AudioDeviceType.airPlay,
    audio.AudioDeviceType.hdmi,
    audio.AudioDeviceType.usbAudio,
    audio.AudioDeviceType.carAudio,
  };

  Future<void> setupDeviceChangeListener() async {
    try {
      final session = await audio.AudioSession.instance;

      final devices = await session.getDevices(includeInputs: false);
      final hasExternalOutput = devices.any(
        (d) => externalAudioOutputTypes.contains(d.type),
      );
      if (hasExternalOutput) {
        _hasExternalOutput = true;
        await _autoSetSpeakerphone(false);
      }

      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        logger.i('Headphones unplugged, restoring to speaker.');
        _hasExternalOutput = false;
        _autoSetSpeakerphone(true);
      });

      _devicesChangedSubscription = session.devicesChangedEventStream.listen((
        event,
      ) {
        final addedExternal = event.devicesAdded
            .where((d) => d.isOutput)
            .any((d) => externalAudioOutputTypes.contains(d.type));
        final removedExternal = event.devicesRemoved
            .where((d) => d.isOutput)
            .any((d) => externalAudioOutputTypes.contains(d.type));

        if (addedExternal) {
          logger.i('External audio output connected, routing to headphones.');
          _hasExternalOutput = true;
          // Remove speaker override so OS routes to the newly connected device.
          _autoSetSpeakerphone(false);
        } else if (removedExternal) {
          logger.i('External audio output disconnected, switching to speaker.');
          _hasExternalOutput = false;
          _autoSetSpeakerphone(true);
        }
      });
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to setup device change listener',
      );
    }
  }

  String? get selectedCameraDeviceId {
    final userTrack = room?.localParticipant
        ?.getTrackPublications()
        .firstWhereOrNull((track) => track.kind == TrackType.VIDEO)
        ?.track;
    if (userTrack?.currentOptions is CameraCaptureOptions) {
      return (userTrack!.currentOptions as CameraCaptureOptions).deviceId;
    }
    return room
        // ignore: invalid_use_of_internal_member
        ?.engine
        .roomOptions
        .defaultCameraCaptureOptions
        .deviceId;
  }

  LocalVideoTrack? get localVideoTrack {
    return room?.localParticipant?.videoTrackPublications
        .where(
          (t) => t.track != null && t.track!.isActive && !t.track!.muted,
        )
        .firstOrNull
        ?.track;
  }

  Future<void> switchCameraPosition() async {
    try {
      final track = localVideoTrack;
      if (track != null) {
        final newPosition = (track.currentOptions as CameraCaptureOptions)
            .cameraPosition
            .switched();
        await track.setCameraPosition(newPosition);
        logger.i('Switched camera to $newPosition');
      } else {
        await room?.localParticipant?.publishVideoTrack(
          await LocalVideoTrack.createCameraTrack(
            Session.defaultCameraCaptureOptions,
          ),
        );
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to switch camera position',
      );
    } finally {
      ref.notifyListeners();
    }
  }

  LocalAudioTrack? get localAudioTrack {
    return room?.localParticipant?.audioTrackPublications.firstOrNull?.track;
  }

  bool get isSpeakerphoneEnabled => room?.speakerOn ?? false;

  Future<void> setSpeakerphone(bool enabled) async {
    // When external audio is connected and the user enables the speaker,
    // this is a temporary override — don't change the base preference.
    if (!_hasExternalOutput) {
      _userSpeakerPreference = enabled;
    }
    await _autoSetSpeakerphone(enabled);
  }

  Future<void> _autoSetSpeakerphone(bool enabled) async {
    await room?.setSpeakerOn(enabled);
    state = state.copyWith(isSpeakerphoneEnabled: enabled);
  }

  String? get selectedAudioDeviceId => localAudioTrack?.currentOptions.deviceId;

  Future<void> selectAudioDevice(MediaDevice device) async {
    final track = localAudioTrack;
    if (track != null) {
      track.setDeviceId(device.deviceId);
    } else {
      await room?.localParticipant?.publishAudioTrack(
        await LocalAudioTrack.create(
          AudioCaptureOptions(deviceId: device.deviceId),
        ),
      );
    }

    // See https://github.com/livekit/client-sdk-flutter/issues/959
    await room?.setAudioInputDevice(device);
    ref.notifyListeners();
  }

  String? get selectedAudioOutputDeviceId {
    // ignore: invalid_use_of_internal_member
    return room?.engine.roomOptions.defaultAudioOutputOptions.deviceId;
  }

  Future<void> selectAudioOutputDevice(MediaDevice device) async {
    // See https://github.com/livekit/client-sdk-flutter/issues/858
    await room?.setAudioOutputDevice(device);
    ref.notifyListeners();
  }

  bool get isMicrophoneEnabled =>
      room?.localParticipant?.isMicrophoneEnabled() ?? false;
  Future<void> enableMicrophone() async {
    if (room?.localParticipant?.isMicrophoneEnabled() ?? false) return;
    if (state.roomState.status == RoomStatus.active && !state.hasKeeper) return;

    if (room?.localParticipant != null) {
      await room?.localParticipant?.setMicrophoneEnabled(true);
    }
    ref.notifyListeners();
  }

  Future<void> disableMicrophone() async {
    if (!(room?.localParticipant?.isMicrophoneEnabled() ?? false)) {
      return;
    }
    try {
      await room?.localParticipant?.setMicrophoneEnabled(false);
      ref.notifyListeners();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disable microphone',
      );
    }
  }

  bool get isCameraEnabled =>
      room?.localParticipant?.isCameraEnabled() ?? false;
  Future<void> enableCamera() async {
    if (room?.localParticipant?.isCameraEnabled() ?? false) {
      return;
    }
    await room?.localParticipant?.setCameraEnabled(
      true,
      cameraCaptureOptions: Session.defaultCameraCaptureOptions.copyWith(
        deviceId: room?.selectedVideoInputDeviceId,
      ),
    );

    ref.notifyListeners();
  }

  Future<void> disableCamera() async {
    if (!(room?.localParticipant?.isCameraEnabled() ?? false)) {
      return;
    }
    await room?.localParticipant?.setCameraEnabled(false);

    ref.notifyListeners();
  }
}
