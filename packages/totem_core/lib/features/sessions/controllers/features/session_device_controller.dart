// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/media_devices_provider.dart';
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
    this.supportsAudioOutputSelection = true,
    this.supportsAudioOutputChooser = false,
    this.isMicrophoneOn = false,
    this.isCameraOn = false,
    this.hasMicrophoneTrack = false,
    this.cameraFacing,
    this.microphoneProblem,
    this.cameraProblem,
  });

  final String? selectedCameraDeviceId;
  final String? selectedAudioOutputDeviceId;
  final bool isSpeakerphoneEnabled;
  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final bool supportsAudioOutputSelection;
  final bool supportsAudioOutputChooser;

  /// What the microphone and camera controls show: the track's state, or what
  /// joining will do until the track is first published.
  final bool isMicrophoneOn;
  final bool isCameraOn;

  /// Whether a microphone track is published, muted or not.
  final bool hasMicrophoneTrack;

  /// The facing of the active camera, or null while the camera is off.
  final CameraFacing? cameraFacing;

  /// Why each device isn't working, when its permission is fine.
  final DeviceProblem? microphoneProblem;
  final DeviceProblem? cameraProblem;

  DeviceProblem? problemOf(MediaKind kind) => switch (kind) {
    MediaKind.camera => cameraProblem,
    MediaKind.microphone => microphoneProblem,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionDeviceState) return false;
    return other.selectedCameraDeviceId == selectedCameraDeviceId &&
        other.selectedAudioOutputDeviceId == selectedAudioOutputDeviceId &&
        other.isSpeakerphoneEnabled == isSpeakerphoneEnabled &&
        other.isMicrophoneEnabled == isMicrophoneEnabled &&
        other.isCameraEnabled == isCameraEnabled &&
        other.supportsAudioOutputSelection == supportsAudioOutputSelection &&
        other.supportsAudioOutputChooser == supportsAudioOutputChooser &&
        other.isMicrophoneOn == isMicrophoneOn &&
        other.isCameraOn == isCameraOn &&
        other.hasMicrophoneTrack == hasMicrophoneTrack &&
        other.cameraFacing == cameraFacing &&
        other.microphoneProblem == microphoneProblem &&
        other.cameraProblem == cameraProblem;
  }

  @override
  int get hashCode => Object.hash(
    selectedCameraDeviceId,
    selectedAudioOutputDeviceId,
    isSpeakerphoneEnabled,
    isMicrophoneEnabled,
    isCameraEnabled,
    supportsAudioOutputSelection,
    supportsAudioOutputChooser,
    isMicrophoneOn,
    isCameraOn,
    hasMicrophoneTrack,
    cameraFacing,
    microphoneProblem,
    cameraProblem,
  );
}

/// Why the session didn't turn a device on. Nothing changes until the user
/// tries again.
enum TurnOnBlocker {
  /// Nobody may speak while the keeper is away.
  keeperAway,

  /// There's no room to take the device's track, or the room couldn't take
  /// it, such as while the connection is down.
  connection,
}

@riverpod
class SessionDeviceController extends _$SessionDeviceController {
  /// Whether each track has been published at least once. Until then the
  /// controls show the user's join preference; afterwards a missing track
  /// means off, so the controls can always republish it.
  bool _microphoneWasPublished = false;
  bool _cameraWasPublished = false;

  SessionDeviceState _currentState() {
    final media = _media;
    return SessionDeviceState(
      selectedCameraDeviceId: selectedCameraDeviceId,
      selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
      isSpeakerphoneEnabled: isSpeakerphoneEnabled,
      isMicrophoneEnabled: isMicrophoneEnabled,
      isCameraEnabled: isCameraEnabled,
      supportsAudioOutputSelection: media.supportsAudioOutputSelection,
      supportsAudioOutputChooser: media.supportsAudioOutputChooser,
      isMicrophoneOn: _microphoneWasPublished
          ? media.isMicrophoneEnabled
          : session.shouldEnableMicrophone(),
      isCameraOn: _cameraWasPublished
          ? media.isCameraEnabled
          : session.options.cameraEnabled,
      hasMicrophoneTrack: media.hasMicrophoneTrack,
      cameraFacing: media.cameraFacing,
      microphoneProblem: _problems[MediaKind.microphone],
      cameraProblem: _problems[MediaKind.camera],
    );
  }

  void _notePublishedTracks() {
    _microphoneWasPublished |= _media.hasMicrophoneTrack;
    _cameraWasPublished |= _media.hasCameraTrack;
  }

  void _emitState() {
    _notePublishedTracks();
    state = _currentState();
  }

  /// Recomputes the controls after the session's state changes, since they
  /// follow it until each track is first published.
  void syncWithSession() => _emitState();

  @override
  SessionDeviceState build(SessionController session) {
    final mediaChanges = _media.changes.listen((_) => _emitState());
    final captureLost = _media.captureLost.listen(_onCaptureLost);
    ref
      ..onDispose(mediaChanges.cancel)
      ..onDispose(captureLost.cancel)
      ..onDispose(_deviceNeedsAttention.close)
      ..onDispose(_turnOnBlocked.close)
      ..onDispose(dispose);
    _notePublishedTracks();
    return _currentState();
  }

  LocalMedia get _media => session.localMedia;

  MediaPermissionController get _permissions =>
      ref.read(mediaPermissionControllerProvider.notifier);

  /// Why each device isn't working, when its permission is fine: set from
  /// a failed capture or a capture that stopped on its own, and cleared when
  /// the device comes on or the user turns it off.
  final _problems = <MediaKind, DeviceProblem?>{};

  /// Each device's commands run one at a time, in order.
  final Map<MediaKind, Future<void>> _queues = {};

  /// Counts each device's turn-on and turn-off requests. A request still
  /// waiting when a later one arrives is dropped, so rapid toggles end in
  /// the latest choice without a burst of captures, and a failure that lands
  /// after the user changed their mind isn't shown.
  final Map<MediaKind, int> _requests = {
    for (final kind in MediaKind.values) kind: 0,
  };

  int _request(MediaKind kind) => _requests[kind] = _requests[kind]! + 1;

  bool _isLatest(MediaKind kind, int request) => request == _requests[kind];

  /// Runs [command] after the device's earlier commands, or straight away
  /// when there are none.
  Future<T> _enqueue<T>(MediaKind kind, Future<T> Function() command) {
    final previous = _queues[kind];
    final result = previous == null
        ? command()
        : previous.then((_) => command());
    final done = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queues[kind] = done;
    unawaited(
      done.whenComplete(() {
        if (identical(_queues[kind], done)) _queues.remove(kind);
      }),
    );
    return result;
  }

  void _setProblem(MediaKind kind, DeviceProblem? problem) {
    _problems[kind] = problem;
    if (!_disposed) _emitState();
  }

  bool _isOn(MediaKind kind) => switch (kind) {
    MediaKind.camera => _media.isCameraEnabled,
    MediaKind.microphone => _media.isMicrophoneEnabled,
  };

  Future<void> _setEnabled(MediaKind kind, bool enabled) => switch (kind) {
    MediaKind.camera => _media.setCameraEnabled(enabled),
    MediaKind.microphone => _media.setMicrophoneEnabled(enabled),
  };

  /// The session's [kind], for the shared turn-on and recovery flow.
  MediaControl control(MediaKind kind) => MediaControl(
    kind: kind,
    problem: sessionDeviceControllerProvider(
      session,
    ).select((state) => state.problemOf(kind)),
    turnOn: () => turnOn(kind),
  );

  /// Turns [kind] on. A capture failure is recorded with the permission
  /// state, which explains its fix; anything the session itself stands in
  /// the way of is announced through [turnOnBlocked].
  Future<TurnOnOutcome> turnOn(MediaKind kind) {
    final request = _request(kind);
    return _enqueue(kind, () => _turnOn(kind, request));
  }

  Future<TurnOnOutcome> _turnOn(MediaKind kind, int request) async {
    if (_disposed || !_isLatest(kind, request)) return const TurnOnSkipped();
    if (!_media.isAvailable) {
      _turnOnBlocked.add((kind, TurnOnBlocker.connection));
      return const TurnOnSkipped();
    }
    if (_isOn(kind)) {
      // Already capturing, so any earlier problem no longer holds.
      _setProblem(kind, null);
      return const TurnedOn();
    }
    if (kind == MediaKind.microphone &&
        session.state.roomState.status == RoomStatus.active &&
        !session.state.hasKeeper) {
      _turnOnBlocked.add((kind, TurnOnBlocker.keeperAway));
      return const TurnOnSkipped();
    }
    try {
      await _setEnabled(kind, true);
    } on MediaPublishException catch (error) {
      if (_disposed) return const TurnOnSkipped();
      logger.w('The room could not take the ${kind.name}', error: error);
      // The device was captured, which proves its permission (WS1).
      _permissions.recordCaptureSuccess(kind);
      // The user changed their mind while it started: the failure is moot.
      if (!_isLatest(kind, request)) return const TurnOnSkipped();
      _turnOnBlocked.add((kind, TurnOnBlocker.connection));
      _emitState();
      return const TurnOnSkipped();
    } catch (error, stackTrace) {
      if (_disposed) return const TurnOnSkipped();
      final failure = await _permissions.recordCaptureFailure(
        kind,
        error,
        stackTrace,
      );
      // The user changed their mind while it started: the failure is moot.
      if (!_isLatest(kind, request)) return const TurnOnSkipped();
      _setProblem(kind, failure.problem);
      return TurnOnFailed(failure);
    }
    if (_disposed) return const TurnOnSkipped();
    // The room went away meanwhile, so nothing was captured.
    if (!_isOn(kind)) {
      _turnOnBlocked.add((kind, TurnOnBlocker.connection));
      return const TurnOnSkipped();
    }
    _permissions.recordCaptureSuccess(kind);
    _setProblem(kind, null);
    return const TurnedOn();
  }

  Future<void> _turnOff(MediaKind kind) {
    final request = _request(kind);
    return _enqueue(kind, () async {
      if (_disposed || !_isLatest(kind, request)) return;
      _problems[kind] = null;
      // Sent even when the device reads off: the join publishes it on the
      // media's own queue, so it can read off while a publish is in flight.
      // The media runs this after that publish, and does nothing when
      // there's nothing published.
      if (_media.isAvailable) {
        try {
          await _setEnabled(kind, false);
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Failed to turn off the ${kind.name}',
          );
        }
      }
      if (!_disposed) _emitState();
    });
  }

  final _turnOnBlocked =
      StreamController<(MediaKind, TurnOnBlocker)>.broadcast();

  /// Emits a device the user tried to turn on that can't be turned on right
  /// now, and why, so they can be told instead of the tap doing nothing.
  Stream<(MediaKind, TurnOnBlocker)> get turnOnBlocked => _turnOnBlocked.stream;

  final _deviceNeedsAttention = StreamController<MediaKind>.broadcast();

  /// Emits a device the user was relying on that isn't working, so they can
  /// be told: it stopped on its own while it was on, such as when its
  /// permission was revoked mid-call, or it was flagged with
  /// [flagNeedsAttention].
  Stream<MediaKind> get deviceNeedsAttention => _deviceNeedsAttention.stream;

  /// Tells the user [kind] isn't working when they need it, such as the
  /// microphone not coming on with the totem.
  void flagNeedsAttention(MediaKind kind) {
    if (!_disposed && !_deviceNeedsAttention.isClosed) {
      _deviceNeedsAttention.add(kind);
    }
  }

  /// Permissions can change at any time, not just before joining (X13).
  /// The device stays off with a problem until the user turns it on, and a
  /// refresh learns whether its permission was revoked.
  void _onCaptureLost(CaptureLost lost) {
    if (_disposed) return;
    _setProblem(lost.kind, DeviceProblem.lost);
    unawaited(_permissions.refresh());
    if (lost.wasOn) flagNeedsAttention(lost.kind);
  }

  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<audio.AudioDevicesChangedEvent>?
  _devicesChangedSubscription;
  Future<void>? _deviceListenerSetup;
  int _deviceListenerGeneration = 0;
  bool _disposed = false;
  bool _userSpeakerPreference = true;
  bool _hasExternalOutput = false;
  bool _audioRouteNotificationsEnabled = false;
  bool? _systemSpeakerphoneEnabled;
  Future<void> _speakerphoneQueue = Future.value();
  int _speakerphoneRequest = 0;

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
    _speakerphoneRequest++;
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
    if (kIsWeb) return;
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
        } else if (removedExternal) {
          logger.i('External audio output disconnected, switching to speaker.');
          _hasExternalOutput = false;
          unawaited(_autoSetSpeakerphone(true));
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

  Future<void> setCameraFacing(CameraFacing facing) =>
      _switchCamera(() => _media.setCameraFacing(facing));

  Future<void> switchCameraPosition() =>
      _switchCamera(_media.switchCameraFacing);

  bool get isSpeakerphoneEnabled =>
      _systemSpeakerphoneEnabled ?? _media.isSpeakerOutputPreferred;

  Future<void> _refreshSpeakerphoneState({bool emit = true}) async {
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
        if (emit) _emitState();
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
    if (kIsWeb) return;
    if (!_hasExternalOutput) {
      _userSpeakerPreference = enabled;
    }
    await _autoSetSpeakerphone(enabled);
  }

  Future<void> _autoSetSpeakerphone(bool enabled) {
    final request = ++_speakerphoneRequest;
    final result = _speakerphoneQueue.then((_) async {
      if (_disposed || request != _speakerphoneRequest || !_media.isAvailable) {
        return;
      }
      await _media.setSpeakerOutputPreferred(enabled);
      if (_disposed || request != _speakerphoneRequest) return;
      await _refreshSpeakerphoneState(emit: false);
      if (_disposed || request != _speakerphoneRequest) return;
      _emitState();
    });
    _speakerphoneQueue = result.catchError((Object _) {});
    return result;
  }

  String? get selectedAudioOutputDeviceId => _media.audioOutputDeviceId;

  Future<void> selectAudioOutputDevice(MediaDeviceInfo device) async {
    try {
      await _media.selectAudioOutput(device);
      _emitState();
    } catch (error, stackTrace) {
      logger.w(
        'Failed to select audio output.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> requestAudioOutputDevice() async {
    try {
      await _media.requestAudioOutput();
      // selectAudioOutput() grants may expose devices without firing
      // navigator.mediaDevices.devicechange.
      ref.invalidate(mediaDevicesProvider);
      _emitState();
    } catch (error, stackTrace) {
      logger.w(
        'Failed to open the browser audio-output chooser.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool get isMicrophoneEnabled => _media.isMicrophoneEnabled;

  Future<void> disableMicrophone() => _turnOff(MediaKind.microphone);

  bool get isCameraEnabled => _media.isCameraEnabled;

  Future<void> disableCamera() => _turnOff(MediaKind.camera);

  Future<void> selectCameraDevice(MediaDeviceInfo device) async {
    if (!_media.isAvailable) return;
    await _switchCamera(() => _media.selectCamera(device));
  }

  /// Switching cameras captures again, so it can fail like turning the
  /// camera on, and a failure is recorded and shown the same way (X9, X13).
  Future<void> _switchCamera(Future<void> Function() change) {
    const kind = MediaKind.camera;
    final request = _requests[kind]!;
    return _enqueue(kind, () async {
      if (_disposed) return;
      final wasOn = _isOn(kind);
      try {
        await change();
      } catch (error, stackTrace) {
        if (_disposed) return;
        final failure = await _permissions.recordCaptureFailure(
          kind,
          error,
          stackTrace,
        );
        if (_isLatest(kind, request)) {
          _problems[kind] = failure.problem;
          // The user was on camera and it dropped, so tell them (X13).
          if (wasOn) flagNeedsAttention(kind);
        }
        // The old capture is gone; show the camera off, with its problem.
        try {
          await _media.setCameraEnabled(false);
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Failed to turn off the camera after a failed switch',
          );
        }
      } finally {
        if (!_disposed) _emitState();
      }
    });
  }

  Future<void> stopDeviceChangeListener() async {
    ++_deviceListenerGeneration;
    ++_speakerphoneRequest;
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
    await stopDeviceChangeListener();
  }
}
