// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:audio_session/audio_session.dart' as audio;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/shared/logger.dart';

part 'session_device_controller.g.dart';

@immutable
class SessionDeviceState {
  const SessionDeviceState({
    required this.selectedCameraDeviceId,
    required this.selectedAudioDeviceId,
    required this.selectedAudioOutputDeviceId,
    required this.isSpeakerphoneEnabled,
    required this.isMicrophoneEnabled,
    required this.isCameraEnabled,
  });

  final String? selectedCameraDeviceId;
  final String? selectedAudioDeviceId;
  final String? selectedAudioOutputDeviceId;
  final bool isSpeakerphoneEnabled;
  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;

  SessionDeviceState copyWith({
    String? selectedCameraDeviceId,
    String? selectedAudioDeviceId,
    String? selectedAudioOutputDeviceId,
    bool? isSpeakerphoneEnabled,
    bool? isMicrophoneEnabled,
    bool? isCameraEnabled,
  }) {
    return SessionDeviceState(
      selectedCameraDeviceId:
          selectedCameraDeviceId ?? this.selectedCameraDeviceId,
      selectedAudioDeviceId:
          selectedAudioDeviceId ?? this.selectedAudioDeviceId,
      selectedAudioOutputDeviceId:
          selectedAudioOutputDeviceId ?? this.selectedAudioOutputDeviceId,
      isSpeakerphoneEnabled:
          isSpeakerphoneEnabled ?? this.isSpeakerphoneEnabled,
      isMicrophoneEnabled: isMicrophoneEnabled ?? this.isMicrophoneEnabled,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionDeviceState) return false;
    return other.selectedCameraDeviceId == selectedCameraDeviceId &&
        other.selectedAudioDeviceId == selectedAudioDeviceId &&
        other.selectedAudioOutputDeviceId == selectedAudioOutputDeviceId &&
        other.isSpeakerphoneEnabled == isSpeakerphoneEnabled &&
        other.isMicrophoneEnabled == isMicrophoneEnabled &&
        other.isCameraEnabled == isCameraEnabled;
  }

  @override
  int get hashCode {
    return selectedCameraDeviceId.hashCode ^
        selectedAudioDeviceId.hashCode ^
        selectedAudioOutputDeviceId.hashCode ^
        isSpeakerphoneEnabled.hashCode ^
        isMicrophoneEnabled.hashCode ^
        isCameraEnabled.hashCode;
  }
}

@Riverpod(keepAlive: true)
class SessionDeviceController extends _$SessionDeviceController {
  SessionDeviceState _currentState() {
    return SessionDeviceState(
      selectedCameraDeviceId: selectedCameraDeviceId,
      selectedAudioDeviceId: selectedAudioDeviceId,
      selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
      isSpeakerphoneEnabled: isSpeakerphoneEnabled,
      isMicrophoneEnabled: isMicrophoneEnabled,
      isCameraEnabled: isCameraEnabled,
    );
  }

  void _emitState() {
    state = _currentState();
  }

  @override
  SessionDeviceState build(SessionController session) {
    return _currentState();
  }

  Room? get _room => this.session.room;

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
      } else {
        _emitState();
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
        } else {
          _emitState();
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
      _emitState();
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
    _emitState();
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
    _emitState();
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
    _emitState();
  }

  bool get isMicrophoneEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  Future<void> enableMicrophone() async {
    final room = _room;
    if (room?.localParticipant?.isMicrophoneEnabled() ?? false) return;
    if (this.session.state.roomState.status == RoomStatus.active &&
        !this.session.state.hasKeeper) {
      return;
    }

    if (room?.localParticipant != null) {
      await room?.localParticipant?.setMicrophoneEnabled(true);
    }
    _emitState();
  }

  Future<void> disableMicrophone() async {
    final room = _room;
    if (!(room?.localParticipant?.isMicrophoneEnabled() ?? false)) {
      return;
    }
    try {
      await room?.localParticipant?.setMicrophoneEnabled(false);
      _emitState();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disable microphone',
      );
    }
  }

  TrackPublication<Track>? get _cameraPublication {
    return _room?.localParticipant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
  }

  bool get _isCameraEnabled {
    final publication = _cameraPublication;
    if (publication == null) return false;

    final track = publication.track;
    final isMuted = track?.muted ?? publication.muted;
    final isActive = track?.isActive ?? true;
    return isActive && !isMuted;
  }

  bool get isCameraEnabled => _isCameraEnabled;

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

    _emitState();
  }

  Future<void> disableCamera() async {
    final room = _room;
    if (!(room?.localParticipant?.isCameraEnabled() ?? false)) {
      return;
    }
    await room?.localParticipant?.setCameraEnabled(false);

    _emitState();
  }

  Future<void> dispose() async {
    await _becomingNoisySubscription?.cancel();
    _becomingNoisySubscription = null;
    await _devicesChangedSubscription?.cancel();
    _devicesChangedSubscription = null;
  }
}
