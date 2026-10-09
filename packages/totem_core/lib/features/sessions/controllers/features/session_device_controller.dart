// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio;
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/shared/logger.dart';

part 'session_device_controller.g.dart';

@immutable
class SessionDeviceState {
  const SessionDeviceState({
    required this.selectedCameraDeviceId,
    required this.selectedAudioOutputDeviceId,
    required this.isSpeakerphoneEnabled,
    required this.isMicrophoneEnabled,
    required this.isCameraEnabled,
    this.isMicrophoneOn = false,
    this.isCameraOn = false,
    this.hasMicrophoneTrack = false,
    this.cameraFacing,
  });

  final String? selectedCameraDeviceId;
  final String? selectedAudioOutputDeviceId;
  final bool isSpeakerphoneEnabled;
  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;

  /// What the microphone and camera controls show: the published track's
  /// state, or the user's join preference until that track is published.
  final bool isMicrophoneOn;
  final bool isCameraOn;

  /// Whether a microphone track is published, muted or not.
  final bool hasMicrophoneTrack;

  /// The facing of the active camera, or null while the camera is off.
  final CameraFacing? cameraFacing;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionDeviceState) return false;
    return other.selectedCameraDeviceId == selectedCameraDeviceId &&
        other.selectedAudioOutputDeviceId == selectedAudioOutputDeviceId &&
        other.isSpeakerphoneEnabled == isSpeakerphoneEnabled &&
        other.isMicrophoneEnabled == isMicrophoneEnabled &&
        other.isCameraEnabled == isCameraEnabled &&
        other.isMicrophoneOn == isMicrophoneOn &&
        other.isCameraOn == isCameraOn &&
        other.hasMicrophoneTrack == hasMicrophoneTrack &&
        other.cameraFacing == cameraFacing;
  }

  @override
  int get hashCode => Object.hash(
    selectedCameraDeviceId,
    selectedAudioOutputDeviceId,
    isSpeakerphoneEnabled,
    isMicrophoneEnabled,
    isCameraEnabled,
    isMicrophoneOn,
    isCameraOn,
    hasMicrophoneTrack,
    cameraFacing,
  );
}

@riverpod
class SessionDeviceController extends _$SessionDeviceController {
  SessionDeviceState _currentState() {
    final media = _media;
    return SessionDeviceState(
      selectedCameraDeviceId: selectedCameraDeviceId,
      selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
      isSpeakerphoneEnabled: isSpeakerphoneEnabled,
      isMicrophoneEnabled: isMicrophoneEnabled,
      isCameraEnabled: isCameraEnabled,
      isMicrophoneOn: media.hasMicrophoneTrack
          ? media.isMicrophoneEnabled
          : session.options.microphoneEnabled,
      isCameraOn: media.hasCameraTrack
          ? media.isCameraEnabled
          : session.options.cameraEnabled,
      hasMicrophoneTrack: media.hasMicrophoneTrack,
      cameraFacing: media.cameraFacing,
    );
  }

  void _emitState() {
    state = _currentState();
  }

  @override
  SessionDeviceState build(SessionController session) {
    final mediaChanges = _media.changes.listen((_) => _emitState());
    ref
      ..onDispose(mediaChanges.cancel)
      ..onDispose(dispose);
    return _currentState();
  }

  LocalMedia get _media => session.localMedia;

  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<audio.AudioDevicesChangedEvent>?
  _devicesChangedSubscription;
  Future<void>? _deviceListenerSetup;
  int _deviceListenerGeneration = 0;
  bool _disposed = false;
  Future<void>? _cameraTransition;
  bool? _desiredCameraEnabled;
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

  bool _isDeviceListenerSetupCurrent(int generation) =>
      !_disposed && generation == _deviceListenerGeneration;

  Future<void> setupDeviceChangeListener() {
    if (_disposed) return Future.value();
    final setup = _deviceListenerSetup;
    if (setup != null) return setup;

    final generation = ++_deviceListenerGeneration;
    final newSetup = _setupDeviceChangeListener(generation);
    _deviceListenerSetup = newSetup;
    return newSetup;
  }

  Future<void> _setupDeviceChangeListener(int generation) async {
    try {
      final session = await audio.AudioSession.instance;
      if (!_isDeviceListenerSetupCurrent(generation)) return;
      await _refreshSpeakerphoneState();
      if (!_isDeviceListenerSetupCurrent(generation)) return;

      final devices = await session.getDevices(includeInputs: false);
      if (!_isDeviceListenerSetupCurrent(generation)) return;
      final hasExternalOutput = devices.any(
        (d) => externalAudioOutputTypes.contains(d.type),
      );
      if (!_isDeviceListenerSetupCurrent(generation)) return;
      if (hasExternalOutput) {
        _hasExternalOutput = true;
        await _autoSetSpeakerphone(false);
      } else {
        await _autoSetSpeakerphone(_userSpeakerPreference);
      }

      if (!_isDeviceListenerSetupCurrent(generation)) return;
      await _becomingNoisySubscription?.cancel();
      await _devicesChangedSubscription?.cancel();
      if (!_isDeviceListenerSetupCurrent(generation)) return;

      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        if (!_isDeviceListenerSetupCurrent(generation)) return;
        logger.i('Headphones unplugged, restoring to speaker.');
        _hasExternalOutput = false;
        unawaited(_autoSetSpeakerphone(true));
        unawaited(_refreshSpeakerphoneState());
      });

      _devicesChangedSubscription = session.devicesChangedEventStream.listen((
        event,
      ) {
        if (!_isDeviceListenerSetupCurrent(generation)) return;
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
    } catch (error, stackTrace) {
      if (_isDeviceListenerSetupCurrent(generation)) {
        _deviceListenerSetup = null;
      }
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to setup device change listener',
      );
    } finally {
      if (_isDeviceListenerSetupCurrent(generation)) {
        _audioRouteNotificationsEnabled = true;
      }
    }
  }

  String? get selectedCameraDeviceId => _media.cameraDeviceId;

  Future<void> switchCameraPosition() async {
    try {
      await _media.switchCameraFacing();
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

  bool get isSpeakerphoneEnabled =>
      _systemSpeakerphoneEnabled ?? _media.isSpeakerOutputPreferred;

  Future<void> _refreshSpeakerphoneState() async {
    if (kIsWeb) return;

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
    if (!_media.isAvailable) return;
    await _media.setSpeakerOutputPreferred(enabled);
    await _refreshSpeakerphoneState();
    _emitState();
  }

  String? get selectedAudioOutputDeviceId => _media.audioOutputDeviceId;

  Future<void> selectAudioOutputDevice(MediaDeviceInfo device) async {
    await _media.selectAudioOutput(device);
    _emitState();
  }

  bool get isMicrophoneEnabled => _media.isMicrophoneEnabled;

  Future<void> enableMicrophone() async {
    if (_media.isMicrophoneEnabled) return;
    if (session.state.roomState.status == RoomStatus.active &&
        !session.state.hasKeeper) {
      return;
    }

    if (_media.isAvailable) {
      await _media.setMicrophoneEnabled(true);
    }
    _emitState();
  }

  Future<void> disableMicrophone() async {
    if (!_media.isMicrophoneEnabled) return;
    try {
      await _media.setMicrophoneEnabled(false);
      _emitState();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disable microphone',
      );
    }
  }

  bool get isCameraEnabled => _media.isCameraEnabled;

  Future<void> enableCamera() => _requestCameraState(true);

  Future<void> disableCamera() => _requestCameraState(false);

  Future<void> toggleCamera() {
    return _requestCameraState(!(_desiredCameraEnabled ?? isCameraEnabled));
  }

  Future<void> _requestCameraState(bool enabled) {
    if (_disposed) return Future.value();

    _desiredCameraEnabled = enabled;
    return _cameraTransition ??= _drainCameraState();
  }

  Future<void> _drainCameraState() async {
    try {
      while (!_disposed) {
        final desiredState = _desiredCameraEnabled;
        if (desiredState == null ||
            !_media.isAvailable ||
            session.state.connection.state != RoomConnectionState.connected) {
          _desiredCameraEnabled = null;
          return;
        }

        if (_media.isCameraEnabled == desiredState) {
          _desiredCameraEnabled = null;
          _emitState();
          return;
        }

        try {
          await _media.setCameraEnabled(desiredState);
        } catch (error, stackTrace) {
          logger.e(
            'Failed to change camera state',
            error: error,
            stackTrace: stackTrace,
          );
          if (_desiredCameraEnabled == desiredState) {
            _desiredCameraEnabled = null;
            return;
          }
        }

        if (_disposed ||
            session.state.connection.state != RoomConnectionState.connected) {
          _desiredCameraEnabled = null;
          return;
        }
        if (_desiredCameraEnabled == desiredState) {
          _desiredCameraEnabled = null;
          _emitState();
          return;
        }
        _emitState();
      }
    } finally {
      _cameraTransition = null;
      if (_disposed) _desiredCameraEnabled = null;
    }
  }

  Future<void> selectCameraDevice(MediaDeviceInfo device) async {
    if (!_media.isAvailable) return;
    await _media.selectCamera(device);
    _emitState();
  }

  Future<void> stopDeviceChangeListener() async {
    ++_deviceListenerGeneration;
    _audioRouteNotificationsEnabled = false;
    final becomingNoisySubscription = _becomingNoisySubscription;
    final devicesChangedSubscription = _devicesChangedSubscription;
    _becomingNoisySubscription = null;
    _devicesChangedSubscription = null;
    _deviceListenerSetup = null;
    await becomingNoisySubscription?.cancel();
    await devicesChangedSubscription?.cancel();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _desiredCameraEnabled = null;
    await stopDeviceChangeListener();
  }
}
