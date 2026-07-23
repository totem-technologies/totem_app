// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/shared/logger.dart';

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
  StreamSubscription<List<MediaDevice>>? _webDeviceChangeSubscription;
  bool _userSpeakerPreference = true;
  bool _hasExternalOutput = false;
  bool _audioRouteNotificationsEnabled = false;
  bool? _systemSpeakerphoneEnabled;

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

  /// Whether the controller has finished setting up listeners for audio route changes.
  ///
  /// This is useful for UI to not rely on the presence of external outputs until listeners
  /// are set up.
  ///
  /// Effectively, the Audio Route Changed notification will not be emitted until this is
  /// true, even if there are external outputs present.
  bool get audioRouteNotificationsEnabled => _audioRouteNotificationsEnabled;

  void resetSpeakerRoutingDefaults([bool preference = true]) {
    _userSpeakerPreference = preference;
    _hasExternalOutput = false;
  }

  Future<void> setupDeviceChangeListener() async {
    try {
      if (kIsWeb) {
        await _setupWebDeviceChangeListener();
      } else {
        await _setupNativeDeviceChangeListener();
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to setup device change listener',
      );
    } finally {
      _audioRouteNotificationsEnabled = true;
    }
  }

  Future<void> _setupNativeDeviceChangeListener() async {
    final session = await audio.AudioSession.instance;
    await _refreshSpeakerphoneState();

    final devices = await session.getDevices(includeInputs: false);
    final hasExternalOutput = devices.any(
      (d) => externalAudioOutputTypes.contains(d.type),
    );
    if (hasExternalOutput) {
      _hasExternalOutput = true;
      await _autoSetSpeakerphone(false);
    } else {
      await _autoSetSpeakerphone(_userSpeakerPreference);
    }

    _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
      logger.i('Headphones unplugged, restoring to speaker.');
      _hasExternalOutput = false;
      unawaited(_autoSetSpeakerphone(true));
      unawaited(_refreshSpeakerphoneState());
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
        unawaited(_refreshSpeakerphoneState());
      } else if (removedExternal) {
        logger.i('External audio output disconnected, switching to speaker.');
        _hasExternalOutput = false;
        unawaited(_autoSetSpeakerphone(true));
        unawaited(_refreshSpeakerphoneState());
      } else {
        unawaited(_refreshSpeakerphoneState());
        _emitState();
      }
    });
  }

  /// Sets up device change detection on web via the browser's
  /// `navigator.mediaDevices.ondevicechange` event.
  Future<void> _setupWebDeviceChangeListener() async {
    final devices = await Hardware.instance.audioOutputs();
    _applyWebAudioRouting(devices);
    await _refreshSpeakerphoneState();

    _webDeviceChangeSubscription = Hardware.instance.onDeviceChange.stream
        .listen((allDevices) {
          final outputs = allDevices
              .where((d) => d.kind == 'audiooutput')
              .toList();
          _applyWebAudioRouting(outputs);
          unawaited(_refreshSpeakerphoneState());
          _emitState();
        });
  }

  /// Examines available audio output devices and determines whether an
  /// external output (headphones, bluetooth) is present, then applies the
  /// corresponding speaker routing.
  void _applyWebAudioRouting(List<MediaDevice> outputs) {
    final hasExternal = hasExternalAudioOutput(outputs);
    if (hasExternal && !_hasExternalOutput) {
      logger.i('Web external audio output detected, routing to headphones.');
      _hasExternalOutput = true;
      unawaited(_autoSetSpeakerphone(false));
    } else if (!hasExternal && _hasExternalOutput) {
      logger.i('Web external audio output removed, routing to speaker.');
      _hasExternalOutput = false;
      unawaited(_autoSetSpeakerphone(true));
    }
  }

  /// Heuristic to detect external audio outputs (headphones, bluetooth) from
  /// a list of web audio output devices.
  ///
  /// On web, the API doesn't expose device type information, so we consider
  /// a device "external" if it has a non-empty label that doesn't contain
  /// "Default".
  @visibleForTesting
  static bool hasExternalAudioOutput(List<MediaDevice> outputs) {
    return outputs.any(
      (d) => d.label.isNotEmpty && !d.label.contains('Default'),
    );
  }

  /// Finds the appropriate audio output device to route to on web.
  ///
  /// When [speakerPreferred] is true, returns the default speaker device.
  /// When false (external output preferred), looks for a communications
  /// device (headset/headphones) first, then falls back to the default.
  @visibleForTesting
  static MediaDevice? findSpeakerTarget(
    List<MediaDevice> devices,
    bool speakerPreferred,
  ) {
    if (!speakerPreferred) {
      final commsDevice = devices.firstWhereOrNull(
        (d) => d.label.toLowerCase().contains('communications'),
      );
      if (commsDevice != null) return commsDevice;
    }
    return devices.firstWhereOrNull(
      (d) => d.label.contains('Default') || d.deviceId == 'default',
    );
  }

  String? get selectedCameraDeviceId {
    String? id;
    final room = _room;
    final userTrack = room?.localParticipant
        ?.getTrackPublications()
        .firstWhereOrNull((track) => track.kind == TrackType.VIDEO)
        ?.track;
    if (userTrack?.currentOptions != null &&
        userTrack?.currentOptions is CameraCaptureOptions) {
      id ??= (userTrack!.currentOptions as CameraCaptureOptions).deviceId;
    }
    return id ??= room
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

  bool get isSpeakerphoneEnabled =>
      _systemSpeakerphoneEnabled ??
      AudioManager.instance.isSpeakerOutputPreferred;

  Future<void> _refreshSpeakerphoneState() async {
    if (kIsWeb) {
      try {
        final devices = await Hardware.instance.audioOutputs();
        if (!ref.mounted) return;
        // On web, speakerphone is considered enabled when there are no
        // external audio output devices with non-empty labels.
        final speakerEnabled = !devices.any(
          (d) => d.label.isNotEmpty && !d.label.contains('Default'),
        );
        if (speakerEnabled != _systemSpeakerphoneEnabled) {
          _systemSpeakerphoneEnabled = speakerEnabled;
          _emitState();
        }
      } catch (error, stackTrace) {
        logger.w(
          'Failed to refresh speakerphone state from web',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }

    try {
      bool? speakerEnabled;

      // TODO(totem): Properly check if speakerphone is enabled
      // if (Platform.isAndroid) {
      //   speakerEnabled = await audio.AndroidAudioManager().isSpeakerphoneOn();
      // } else

      if (Platform.isIOS) {
        final session = await audio.AudioSession.instance;
        final outputs = await session.getDevices(includeInputs: false);
        speakerEnabled = outputs.any(
          (d) => d.isOutput && d.type == audio.AudioDeviceType.builtInSpeaker,
        );
      }

      if (speakerEnabled != null &&
          speakerEnabled != _systemSpeakerphoneEnabled) {
        _systemSpeakerphoneEnabled = speakerEnabled;
        _emitState();
      }
    } catch (error, stackTrace) {
      logger.w(
        'Failed to refresh speakerphone state from system',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setSpeakerphone(bool enabled) async {
    if (!_hasExternalOutput) {
      _userSpeakerPreference = enabled;
    }
    await _autoSetSpeakerphone(enabled);
  }

  Future<void> _autoSetSpeakerphone(bool enabled) async {
    if (_room == null) return;

    if (kIsWeb) {
      // On web, attempt to route audio using setSinkId (supported on
      // desktop Chrome/Edge and Safari 17+). On mobile browsers this is
      // usually a no-op, but the preference is tracked for UI purposes.
      try {
        final devices = await Hardware.instance.audioOutputs();
        final target = findSpeakerTarget(devices, enabled);
        if (target != null) {
          await _room?.setAudioOutputDevice(target);
        }
      } catch (error, stackTrace) {
        logger.w(
          'Failed to set audio output on web',
          error: error,
          stackTrace: stackTrace,
        );
      }
      await _refreshSpeakerphoneState();
      _emitState();
      return;
    }

    // There is a bug in the livekit library that doesn't effectively turn the speakerphone
    // on when requested.
    // A workaround is to first turn it off, then set the desired state.
    AudioManager.instance.setSpeakerOutputPreferred(false);

    if (enabled) {
      AudioManager.instance.setSpeakerOutputPreferred(enabled);
    }

    await _refreshSpeakerphoneState();
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

  Future<void> selectCameraDevice(MediaDevice device) async {
    final room = _room;
    if (room == null) return;

    await room.setVideoInputDevice(device);
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
    await _webDeviceChangeSubscription?.cancel();
    _webDeviceChangeSubscription = null;
  }
}
