// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:audio_session/audio_session.dart' as audio;
import 'package:collection/collection.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/session_controller.dart';
import 'package:totem_app/shared/logger.dart';

part 'session_device_controller.g.dart';

@Riverpod(keepAlive: true)
class SessionDeviceController extends _$SessionDeviceController {
  late SessionController _session;

  @override
  void build(SessionController session) {
    _session = session;
  }

  Room? get _room => _session.room;

  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<audio.AudioDevicesChangedEvent>?
  _devicesChangedSubscription;
  bool _userSpeakerPreference = true;
  bool _hasExternalOutput = false;

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

  bool get userSpeakerPreference => _userSpeakerPreference;

  void resetSpeakerRoutingDefaults() {
    _userSpeakerPreference = true;
    _hasExternalOutput = false;
  }

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
        unawaited(_autoSetSpeakerphone(true));
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
          unawaited(_autoSetSpeakerphone(false));
        } else if (removedExternal) {
          logger.i('External audio output disconnected, switching to speaker.');
          _hasExternalOutput = false;
          unawaited(_autoSetSpeakerphone(true));
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
    final room = _room;
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
    return _room?.localParticipant?.videoTrackPublications
        .where(
          (t) => t.track != null && t.track!.isActive && !t.track!.muted,
        )
        .firstOrNull
        ?.track;
  }

  Future<void> switchCameraPosition() async {
    try {
      final room = _room;
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
            SessionController.defaultCameraCaptureOptions,
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
    return _room?.localParticipant?.audioTrackPublications.firstOrNull?.track;
  }

  bool get isSpeakerphoneEnabled => _room?.speakerOn ?? false;

  Future<void> setSpeakerphone(bool enabled) async {
    if (!_hasExternalOutput) {
      _userSpeakerPreference = enabled;
    }
    await _autoSetSpeakerphone(enabled);
  }

  Future<void> _autoSetSpeakerphone(bool enabled) async {
    await _room?.setSpeakerOn(enabled);
    _session.onSpeakerphoneChanged(enabled);
  }

  String? get selectedAudioDeviceId => localAudioTrack?.currentOptions.deviceId;

  Future<void> selectAudioDevice(MediaDevice device) async {
    final room = _room;
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
    return _room
        // ignore: invalid_use_of_internal_member
        ?.engine
        .roomOptions
        .defaultAudioOutputOptions
        .deviceId;
  }

  Future<void> selectAudioOutputDevice(MediaDevice device) async {
    // See https://github.com/livekit/client-sdk-flutter/issues/858
    await _room?.setAudioOutputDevice(device);
    ref.notifyListeners();
  }

  bool get isMicrophoneEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  Future<void> enableMicrophone() async {
    final room = _room;
    if (room?.localParticipant?.isMicrophoneEnabled() ?? false) return;
    if (_session.state.roomState.status == RoomStatus.active &&
        !_session.state.hasKeeper) {
      return;
    }

    if (room?.localParticipant != null) {
      await room?.localParticipant?.setMicrophoneEnabled(true);
    }
    ref.notifyListeners();
  }

  Future<void> disableMicrophone() async {
    final room = _room;
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
      _room?.localParticipant?.isCameraEnabled() ?? false;

  Future<void> enableCamera() async {
    final room = _room;
    if (room?.localParticipant?.isCameraEnabled() ?? false) {
      return;
    }
    await room?.localParticipant?.setCameraEnabled(
      true,
      cameraCaptureOptions: SessionController.defaultCameraCaptureOptions
          .copyWith(
            deviceId: room.selectedVideoInputDeviceId,
          ),
    );

    ref.notifyListeners();
  }

  Future<void> disableCamera() async {
    final room = _room;
    if (!(room?.localParticipant?.isCameraEnabled() ?? false)) {
      return;
    }
    await room?.localParticipant?.setCameraEnabled(false);

    ref.notifyListeners();
  }

  Future<void> dispose() async {
    await _becomingNoisySubscription?.cancel();
    _becomingNoisySubscription = null;
    await _devicesChangedSubscription?.cancel();
    _devicesChangedSubscription = null;
  }
}
