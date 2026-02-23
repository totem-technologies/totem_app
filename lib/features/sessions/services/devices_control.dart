// We need to access LivekitService.ref to notify listeners
// ignore_for_file: experimental_member_use, invalid_use_of_protected_member

part of 'session_service.dart';

extension DevicesControl on Session {
  static const speakerPreferenceKey = 'speaker_preference';

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

      final devices = await session.getDevices(includeOutputs: true);
      final hasExternalOutput = devices
          .where((d) => d.isOutput)
          .any((d) => externalAudioOutputTypes.contains(d.type));
      if (hasExternalOutput) {
        _autoSetSpeakerphone(false);
      }

      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        logger.i(
          'Headphones unplugged, restoring speaker to $_userSpeakerPreference.',
        );
        _autoSetSpeakerphone(_userSpeakerPreference);
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
          logger.i('External audio output connected, disabling speaker.');
          _autoSetSpeakerphone(false);
        } else if (removedExternal) {
          logger.i(
            'External audio output disconnected, restoring speaker to $_userSpeakerPreference.',
          );
          _autoSetSpeakerphone(_userSpeakerPreference);
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
    final userTrack = context?.localParticipant
        ?.getTrackPublications()
        .firstWhereOrNull((track) => track.kind == TrackType.VIDEO)
        ?.track;
    if (userTrack?.currentOptions is CameraCaptureOptions) {
      return (userTrack!.currentOptions as CameraCaptureOptions).deviceId;
    }
    return context
        ?.room
        .engine
        .roomOptions
        .defaultCameraCaptureOptions
        .deviceId;
  }

  LocalVideoTrack? get localVideoTrack {
    return context?.localParticipant?.videoTrackPublications
        .where((t) => t.track != null && t.track!.isActive && !t.track!.muted)
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
        await context?.localParticipant?.publishVideoTrack(
          await LocalVideoTrack.createCameraTrack(Session.defaultCameraOptions),
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
    return context?.localParticipant?.audioTrackPublications.firstOrNull?.track;
  }

  bool get isSpeakerphoneEnabled => context?.room.speakerOn ?? false;

  Future<void> setSpeakerphone(bool enabled) async {
    _userSpeakerPreference = enabled;
    await _autoSetSpeakerphone(enabled);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(DevicesControl.speakerPreferenceKey, enabled),
    );
  }

  Future<void> _autoSetSpeakerphone(bool enabled) async {
    await context?.room.setSpeakerOn(enabled);
    ref.notifyListeners();
  }

  String? get selectedAudioDeviceId => localAudioTrack?.currentOptions.deviceId;

  Future<void> selectAudioDevice(MediaDevice device) async {
    final track = localAudioTrack;
    if (track != null) {
      track.setDeviceId(device.deviceId);
    } else {
      await context?.localParticipant?.publishAudioTrack(
        await LocalAudioTrack.create(
          AudioCaptureOptions(deviceId: device.deviceId),
        ),
      );
    }

    // See https://github.com/livekit/client-sdk-flutter/issues/959
    await context?.room.setAudioInputDevice(device);
    ref.notifyListeners();
  }

  String? get selectedAudioOutputDeviceId {
    return context?.room.engine.roomOptions.defaultAudioOutputOptions.deviceId;
  }

  Future<void> selectAudioOutputDevice(MediaDevice device) async {
    // See https://github.com/livekit/client-sdk-flutter/issues/858
    await context?.room.setAudioOutputDevice(device);
    ref.notifyListeners();
  }

  Future<void> enableMicrophone() async {
    if (context?.microphoneOpened ?? false) return;

    if (context?.localParticipant != null) {
      await context?.localParticipant?.setMicrophoneEnabled(true);
    } else {
      context?.localAudioTrack ??= await LocalAudioTrack.create(
        AudioCaptureOptions(deviceId: context?.room.selectedAudioInputDeviceId),
      );
    }
    ref.notifyListeners();
  }

  Future<void> disableMicrophone() async {
    if (!(context?.microphoneOpened ?? false)) {
      return;
    }
    try {
      if (context?.connected ?? false) {
        await context?.localParticipant?.setMicrophoneEnabled(false);
      } else {
        await context?.localAudioTrack?.dispose();
        context?.localAudioTrack = null;
      }
      ref.notifyListeners();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disable microphone',
      );
    }
  }

  Future<void> enableCamera() async {
    if (context?.cameraOpened ?? false) {
      return;
    }
    if (context?.connected ?? false) {
      await context?.localParticipant?.setCameraEnabled(
        true,
        cameraCaptureOptions: Session.defaultCameraOptions.copyWith(
          deviceId: context?.room.selectedVideoInputDeviceId,
        ),
      );
    } else {
      context?.localVideoTrack ??= await LocalVideoTrack.createCameraTrack(
        Session.defaultCameraOptions.copyWith(
          deviceId: context?.room.selectedVideoInputDeviceId,
        ),
      );
    }

    ref.notifyListeners();
  }

  Future<void> disableCamera() async {
    if (!(context?.cameraOpened ?? false)) {
      return;
    }
    if (context?.connected ?? false) {
      await context?.localParticipant?.setCameraEnabled(false);
    } else {
      await context?.localVideoTrack?.dispose();
      context?.localVideoTrack = null;
    }
    ref.notifyListeners();
  }
}
