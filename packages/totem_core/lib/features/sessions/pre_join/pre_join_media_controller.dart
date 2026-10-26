import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/pre_join/capture.dart';
import 'package:totem_core/features/sessions/pre_join/capture_loop.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_foreground.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';

part 'pre_join_media_controller.g.dart';

abstract class PreJoinPreviewTrackFactory {
  const PreJoinPreviewTrackFactory();

  Future<LocalVideoTrack?> createVideoTrack(CameraCaptureOptions cameraOptions);

  Future<LocalAudioTrack?> createAudioTrack();
}

class LiveKitPreJoinPreviewTrackFactory extends PreJoinPreviewTrackFactory {
  const LiveKitPreJoinPreviewTrackFactory();

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) => LocalVideoTrack.createCameraTrack(cameraOptions);

  @override
  Future<LocalAudioTrack?> createAudioTrack() => LocalAudioTrack.create();
}

final preJoinPreviewTrackFactoryProvider = Provider<PreJoinPreviewTrackFactory>(
  (_) => const LiveKitPreJoinPreviewTrackFactory(),
);

/// A serial operation queue whose tail is guaranteed not to throw.
///
/// Capture APIs must not overlap on cold-start Safari. Keeping failures out of
/// the retained tail also guarantees that one device failure cannot poison all
/// later toggles or joins.
@visibleForTesting
class PreJoinMediaOperationQueue {
  Future<void>? _tail;

  Future<void>? get pending => _tail;

  Future<T> schedule<T>(AsyncValueGetter<T> operation) {
    final previous = _tail;
    final result = () async {
      try {
        await previous;
      } catch (_) {
        // A tail created by this class is non-throwing. This additionally
        // protects callers if the implementation changes in the future.
      }
      return operation();
    }();

    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

/// The pre-join preview's camera and microphone.
///
/// Both devices start wanted. A [CaptureLoop] decides when each is captured:
/// on native once its permission is granted, so the OS prompt only follows
/// the user (X2); on web straight away, since capture is the request (WS2).
/// A permission change, the tab's visibility and the user's toggles all just
/// re-run the loop. Every capture goes through one queue, because cold-start
/// Safari can't take overlapping requests.
@riverpod
class PreJoinMediaController extends _$PreJoinMediaController {
  final _captureOperations = PreJoinMediaOperationQueue();
  late CaptureLoop _loop;

  Future<void>? _initialization;
  bool _started = false;
  LocalVideoTrack? _cameraTrack;
  LocalAudioTrack? _microphoneTrack;
  LocalVideoTrack? _transferredVideoTrack;
  LocalAudioTrack? _transferredAudioTrack;
  bool _terminal = false;
  int _captureGeneration = 0;
  Future<void>? _terminalRelease;
  StreamSubscription<bool>? _foregroundSubscription;
  late PreJoinForegroundMonitor _foregroundMonitor;

  @override
  PreJoinMediaState build(String sessionSlug) {
    _foregroundMonitor = ref.read(preJoinForegroundMonitorProvider);
    _foregroundSubscription = _foregroundMonitor.changes.listen(
      _onForegroundChanged,
    );
    _loop = CaptureLoop(
      start: _start,
      stop: _stop,
      isOn: _isOn,
      permissionOf: (kind) => _permissions.permissionOf(kind),
      platform: () => ref.read(platformInfoProvider),
      available: _available,
      onChanged: _emit,
    );
    for (final kind in MediaKind.values) {
      _loop.setIntent(kind, const DeviceIntent(wanted: true));
    }
    ref
      ..onDispose(() {
        _foregroundSubscription?.cancel();
        unawaited(releaseForTerminalOutcome());
      })
      // A grant from the priming sheet, Settings or site settings starts a
      // device that was waiting for it (X1, X5, X12).
      ..listen<MediaPermissions?>(mediaPermissionControllerProvider, (_, _) {
        // Before the first run, that run sees the latest permission anyway.
        if (!_started) return;
        _emit();
        unawaited(_loop.run());
      });
    _initialization = Future<void>.microtask(() {
      _started = true;
      return _loop.run();
    });
    unawaited(_detectHeadphones());
    return const PreJoinMediaState();
  }

  MediaPermissionController get _permissions =>
      ref.read(mediaPermissionControllerProvider.notifier);

  bool get _foregroundAllows =>
      !_foregroundMonitor.requiresForegroundGate ||
      _foregroundMonitor.isForeground;

  bool _isOn(MediaKind kind) => switch (kind) {
    MediaKind.camera => _cameraTrack != null,
    MediaKind.microphone => _microphoneTrack != null,
  };

  bool _available(MediaKind kind) =>
      ref.mounted &&
      !_terminal &&
      !state.transferred &&
      (kind != MediaKind.camera || _foregroundAllows);

  /// Wants [kind] on and resolves with its outcome once capture settles.
  /// A camera waiting for the tab to come back is skipped: its phase says so.
  Future<TurnOnOutcome> turnOn(MediaKind kind) async {
    if (_terminal || state.transferred) return const TurnOnSkipped();
    final intent = await _loop.turnOn(kind);
    if (_isOn(kind)) return const TurnedOn();
    if (intent.problem case final problem?) {
      return TurnOnFailed(DeviceFailed(problem));
    }
    if (intent.refusedAs case final permission?) {
      return TurnOnFailed(PermissionRefused(permission));
    }
    return const TurnOnSkipped();
  }

  /// Turns [kind] off and releases its preview capture.
  Future<void> turnOff(MediaKind kind) async {
    if (_terminal || state.transferred) return;
    await _loop.turnOff(kind);
  }

  /// Completes once every capture due has run.
  Future<void> settled() async {
    await _initialization;
    await _loop.run();
    await _captureOperations.pending;
  }

  void _onForegroundChanged(bool isForeground) {
    // A camera start in flight while the tab hides is abandoned, and the
    // camera waits for the tab to come back (W6).
    if (!isForeground) _captureGeneration++;
    _emit();
    if (isForeground) unawaited(_loop.run());
  }

  /// Whether the preview still owns its capture.
  bool get _isLive => ref.mounted && !_terminal && !state.transferred;

  /// Whether a camera start begun at [generation] still counts: hiding the
  /// tab abandons it, unlike a microphone start (W6).
  bool _isCurrent(int generation) =>
      _isLive && generation == _captureGeneration;

  Future<CaptureFailure?> _start(MediaKind kind) => switch (kind) {
    MediaKind.camera => _captureOperations.schedule(_startCamera),
    MediaKind.microphone => _captureOperations.schedule(_startMicrophone),
  };

  Future<CaptureFailure?> _startCamera() async {
    final generation = _captureGeneration;
    await _disposeCameraTrack();
    if (!_isCurrent(generation) || !_foregroundAllows) return null;
    LocalVideoTrack? track;
    try {
      track = await ref
          .read(preJoinPreviewTrackFactoryProvider)
          .createVideoTrack(state.preferences.cameraOptions);
      if (_isCurrent(generation) && _foregroundAllows) await track?.start();
    } catch (error, stackTrace) {
      await _disposeTrack(track, 'camera');
      // Abandoned by a hidden tab, not failed: it starts again when visible.
      if (!_isCurrent(generation)) return null;
      return _permissions.recordCaptureFailure(
        MediaKind.camera,
        error,
        stackTrace,
      );
    }
    if (!_isCurrent(generation) || !_foregroundAllows) {
      await _disposeTrack(track, 'camera');
      return null;
    }
    if (track == null) return const DeviceFailed(DeviceProblem.notFound);
    _cameraTrack = track;
    _observeUnexpectedTrackEnd(track, MediaKind.camera);
    _permissions.recordCaptureSuccess(MediaKind.camera);
    return null;
  }

  Future<CaptureFailure?> _startMicrophone() async {
    await _disposeMicrophoneTrack();
    if (!_isLive) return null;
    LocalAudioTrack? track;
    try {
      track = await ref
          .read(preJoinPreviewTrackFactoryProvider)
          .createAudioTrack();
      await track?.enable();
      await track?.start();
      await track?.unmute(stopOnMute: false);
    } catch (error, stackTrace) {
      await _disposeTrack(track, 'microphone');
      if (!_isLive) return null;
      return _permissions.recordCaptureFailure(
        MediaKind.microphone,
        error,
        stackTrace,
      );
    }
    if (!_isLive) {
      await _disposeTrack(track, 'microphone');
      return null;
    }
    if (track == null) return const DeviceFailed(DeviceProblem.notFound);
    _microphoneTrack = track;
    _observeUnexpectedTrackEnd(track, MediaKind.microphone);
    _permissions.recordCaptureSuccess(MediaKind.microphone);
    return null;
  }

  Future<void> _stop(MediaKind kind) =>
      _captureOperations.schedule(switch (kind) {
        MediaKind.camera => _disposeCameraTrack,
        MediaKind.microphone => _disposeMicrophoneTrack,
      });

  /// Publishes what the loop, the tracks and the permissions say.
  void _emit() {
    // Before the first run, the initial state already says uninitialized.
    if (!ref.mounted || !_started) return;
    final cameraPhase = _phaseOf(MediaKind.camera);
    final microphonePhase = _phaseOf(MediaKind.microphone);
    state = state.copyWith(
      preferences: state.preferences.copyWith(
        isCameraOn: _showsOn(MediaKind.camera, cameraPhase),
        isMicOn: _showsOn(MediaKind.microphone, microphonePhase),
      ),
      camera: PreJoinCaptureState(
        phase: cameraPhase,
        track: cameraPhase == PreJoinCapturePhase.ready ? _cameraTrack : null,
        problem: _loop.intentOf(MediaKind.camera).problem,
      ),
      microphone: PreJoinCaptureState(
        phase: microphonePhase,
        track: microphonePhase == PreJoinCapturePhase.ready
            ? _microphoneTrack
            : null,
        problem: _loop.intentOf(MediaKind.microphone).problem,
      ),
    );
  }

  /// A device shows as on while it's wanted and capturing or starting, so a
  /// device waiting for permission shows off and never joins on (X2).
  bool _showsOn(MediaKind kind, PreJoinCapturePhase phase) =>
      _loop.intentOf(kind).wanted &&
      (phase == PreJoinCapturePhase.ready ||
          phase == PreJoinCapturePhase.initializing);

  PreJoinCapturePhase _phaseOf(MediaKind kind) {
    if (!_started) return PreJoinCapturePhase.uninitialized;
    final intent = _loop.intentOf(kind);
    if (state.transferred) {
      // Handed to the session; once the session lets go after a failed
      // join, a wanted device is captured afresh.
      if (_isOn(kind)) return PreJoinCapturePhase.ready;
      return intent.wanted
          ? PreJoinCapturePhase.uninitialized
          : PreJoinCapturePhase.disabled;
    }
    if (_loop.isStarting(kind)) return PreJoinCapturePhase.initializing;
    // A device that stopped on its own stays visibly broken, not just off.
    if (intent.problem != null) return PreJoinCapturePhase.unavailable;
    if (!intent.wanted) return PreJoinCapturePhase.disabled;
    if (_isOn(kind)) return PreJoinCapturePhase.ready;
    final permission = _permissions.permissionOf(kind);
    if (intent.refusedAs == permission) return PreJoinCapturePhase.unavailable;
    if (!_available(kind)) return PreJoinCapturePhase.waitingForForeground;
    // The loop's own decision, so a device never shows as starting while the
    // loop is waiting, or the other way round.
    final effect = nextEffect(
      intent,
      isOn: false,
      permission: () => permission,
      platform: ref.read(platformInfoProvider),
    );
    return effect == CaptureEffect.start
        ? PreJoinCapturePhase.initializing
        : PreJoinCapturePhase.waitingForAccess;
  }

  Future<void> _detectHeadphones() async {
    try {
      final audioSession = await AudioSession.instance;
      final devices = await audioSession.getDevices(includeInputs: false);
      final hasExternalOutput = devices.any(
        (device) => SessionDeviceController.externalAudioOutputTypes.contains(
          device.type,
        ),
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        preferences: state.preferences.copyWith(
          isSpeakerOn: !hasExternalOutput,
        ),
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to detect audio output devices',
      );
    }
  }

  void toggleSpeaker() {
    if (_terminal || state.transferred) return;
    state = state.copyWith(
      preferences: state.preferences.copyWith(
        isSpeakerOn: !state.preferences.isSpeakerOn,
      ),
    );
  }

  void setCameraFacing(CameraFacing facing) {
    _setCameraOptions(
      state.preferences.cameraOptions.copyWith(
        cameraPosition: facing.toLiveKit(),
      ),
    );
  }

  void selectCameraDevice(MediaDeviceInfo device) {
    _setCameraOptions(
      state.preferences.cameraOptions.copyWith(deviceId: device.id),
    );
  }

  void _setCameraOptions(CameraCaptureOptions options) {
    if (_terminal || state.transferred) return;
    state = state.copyWith(
      preferences: state.preferences.copyWith(cameraOptions: options),
    );
    if (_isOn(MediaKind.camera)) unawaited(_restartCamera());
  }

  /// Captures the camera again with new options.
  Future<void> _restartCamera() async {
    await _captureOperations.schedule(_disposeCameraTrack);
    _emit();
    await _loop.run();
  }

  Future<PreJoinMediaState> resetAfterFailedJoin() async {
    if (_terminal) return state;
    detachTransferredTracks();
    await _initialization;
    await _captureOperations.pending;

    // Failed-room teardown owned the transferred tracks. Clear the handoff
    // markers after teardown, then acquire one fresh capture pair.
    _transferredVideoTrack = null;
    _transferredAudioTrack = null;
    _cameraTrack = null;
    _microphoneTrack = null;
    state = state.copyWith(transferred: false);
    _emit();
    await _loop.run();
    return state;
  }

  /// Releases preview media when this screen reaches a terminal outcome.
  ///
  /// Tracks handed to the session remain session-owned and are never disposed
  /// here. Invalidating the capture generation makes a delayed getUserMedia
  /// result self-dispose instead of resurrecting the preview.
  Future<void> releaseForTerminalOutcome() {
    return _terminalRelease ??= _releaseForTerminalOutcome();
  }

  Future<void> _releaseForTerminalOutcome() async {
    _terminal = true;
    _captureGeneration++;
    _loop.close();
    await _initialization;
    await _captureOperations.pending;
    await _disposeOwnedTracks();
  }

  /// Removes transferred tracks from the render state without disposing them.
  ///
  /// The Session owns these tracks after [takeForJoin]. Detaching synchronously
  /// lets it stop failed media without a renderer observing that teardown.
  void detachTransferredTracks() {
    if (!ref.mounted || !state.transferred) return;
    _cameraTrack = null;
    _microphoneTrack = null;
    _emit();
  }

  Future<SessionJoinMedia> takeForJoin() async {
    if (_terminal) {
      throw StateError('Pre-join media has been released');
    }
    if (state.transferred) {
      throw StateError('Pre-join media has already been transferred');
    }
    await settled();

    final cameraTrack = state.camera.isReady ? state.camera.track : null;
    final microphoneTrack = state.microphone.isReady
        ? state.microphone.track
        : null;
    _transferredVideoTrack = cameraTrack;
    _transferredAudioTrack = microphoneTrack;
    state = state.copyWith(transferred: true);
    _emit();
    return SessionJoinMedia(
      cameraTrack: cameraTrack,
      microphoneTrack: microphoneTrack,
      onBeforeDispose: detachTransferredTracks,
    );
  }

  void _observeUnexpectedTrackEnd(LocalTrack track, MediaKind kind) {
    try {
      observeCaptureEnd(track, () => _handleUnexpectedTrackEnd(track, kind));
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to observe pre-join media track state',
      );
    }
  }

  /// A revoked permission or an unplugged device (W9). The device stays off
  /// with a problem, which disables Join for the microphone, and a refresh
  /// learns whether the permission changed.
  void _handleUnexpectedTrackEnd(LocalTrack track, MediaKind kind) {
    if (!ref.mounted || state.transferred) return;
    switch (kind) {
      case MediaKind.camera:
        if (!identical(_cameraTrack, track)) return;
        _cameraTrack = null;
      case MediaKind.microphone:
        if (!identical(_microphoneTrack, track)) return;
        _microphoneTrack = null;
    }
    _loop.lose(kind);
    unawaited(_permissions.refresh());
    // The browser has already ended capture. Dispose the LiveKit wrapper on
    // the same queue as every other media operation.
    unawaited(
      _captureOperations.schedule(() => _disposeTrack(track, kind.name)),
    );
  }

  Future<void> _disposeCameraTrack() async {
    final track = _cameraTrack;
    _cameraTrack = null;
    if (identical(track, _transferredVideoTrack)) return;
    if (track != null) await _disposeTrack(track, 'camera');
  }

  Future<void> _disposeMicrophoneTrack() async {
    final track = _microphoneTrack;
    _microphoneTrack = null;
    if (identical(track, _transferredAudioTrack)) return;
    if (track != null) await _disposeTrack(track, 'microphone');
  }

  Future<void> _disposeOwnedTracks() async {
    final cameraTrack = _cameraTrack;
    final microphoneTrack = _microphoneTrack;
    _cameraTrack = null;
    _microphoneTrack = null;
    await Future.wait([
      if (!identical(cameraTrack, _transferredVideoTrack))
        _disposeTrack(cameraTrack, 'camera'),
      if (!identical(microphoneTrack, _transferredAudioTrack))
        _disposeTrack(microphoneTrack, 'microphone'),
    ]);
  }

  Future<void> _disposeTrack(LocalTrack? track, String kind) async {
    if (track == null) return;
    try {
      await track.stop();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to stop pre-join $kind track',
      );
    }
    try {
      await track.dispose();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to dispose pre-join $kind track',
      );
    }
  }
}
