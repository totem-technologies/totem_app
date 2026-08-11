import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';

part 'pre_join_media_controller.g.dart';

abstract class PreJoinPreviewTrackFactory {
  const PreJoinPreviewTrackFactory();

  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  );

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

class PreJoinMediaPermissionDeniedException implements Exception {
  const PreJoinMediaPermissionDeniedException();
}

/// A serial operation queue whose tail is guaranteed not to throw.
///
/// Capture APIs must not overlap on cold-start Safari. Keeping failures out of
/// the retained tail also guarantees that one device failure cannot poison all
/// later toggles or joins.
@visibleForTesting
class PreJoinMediaOperationQueue {
  Future<void>? _tail;

  Future<void>? get pending => _tail;

  Future<T> schedule<T>(Future<T> Function() operation) {
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

    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}

@riverpod
class PreJoinMediaController extends _$PreJoinMediaController {
  final _captureOperations = PreJoinMediaOperationQueue();

  Future<void>? _initialization;
  LocalVideoTrack? _cameraTrack;
  LocalAudioTrack? _microphoneTrack;
  LocalVideoTrack? _transferredVideoTrack;
  LocalAudioTrack? _transferredAudioTrack;
  bool _togglingCamera = false;
  bool _togglingMicrophone = false;

  @override
  PreJoinMediaState build(String sessionSlug) {
    ref.onDispose(() => unawaited(_disposeOwnedTracks()));
    _initialization = Future<void>.microtask(initialize);
    unawaited(_detectHeadphones());
    return const PreJoinMediaState();
  }

  Future<void> initialize() async {
    // Serialize every getUserMedia path. Safari is sensitive to overlapping
    // capture requests during a cold browser start, including user toggles.
    if (state.preferences.isCameraOn) {
      await _captureOperations.schedule(_initializeCamera);
    } else {
      _setCamera(
        const PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
      );
    }

    // Preferences may change while camera initialization is in flight.
    if (!ref.mounted) return;
    if (state.preferences.isMicOn) {
      if (!state.microphone.isReady) {
        await _captureOperations.schedule(_initializeMicrophone);
      }
    } else if (state.microphone.phase == PreJoinCapturePhase.uninitialized ||
        state.microphone.phase == PreJoinCapturePhase.initializing) {
      _setMicrophone(
        const PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
      );
    }
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

  Future<void> _initializeCamera() async {
    await _disposeCameraTrack();
    if (!ref.mounted || !state.preferences.isCameraOn) return;

    _setCamera(
      const PreJoinCaptureState(phase: PreJoinCapturePhase.initializing),
    );
    LocalVideoTrack? track;
    try {
      track = await ref
          .read(preJoinPreviewTrackFactoryProvider)
          .createVideoTrack(state.preferences.cameraOptions);
      if (!ref.mounted) {
        await _disposeTrack(track, 'camera');
        return;
      }
      if (!state.preferences.isCameraOn) {
        await _disposeTrack(track, 'camera');
        _setCamera(
          const PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
        );
        return;
      }
      await track?.start();
      if (!ref.mounted || !state.preferences.isCameraOn) {
        await _disposeTrack(track, 'camera');
        if (ref.mounted) {
          _setCamera(
            const PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
          );
        }
        return;
      }
      if (track == null) {
        state = state.copyWith(
          preferences: state.preferences.copyWith(isCameraOn: false),
          camera: const PreJoinCaptureState(
            phase: PreJoinCapturePhase.unavailable,
          ),
        );
      } else {
        _cameraTrack = track;
        _observeUnexpectedTrackEnd(track, isCamera: true);
        _setCamera(
          PreJoinCaptureState(
            phase: PreJoinCapturePhase.ready,
            track: track,
          ),
        );
      }
    } catch (error, stackTrace) {
      await _disposeTrack(track, 'camera');
      if (!ref.mounted) return;
      state = state.copyWith(
        preferences: state.preferences.copyWith(isCameraOn: false),
        camera: PreJoinCaptureState(
          phase: _isWebMediaPermissionDenied(error)
              ? PreJoinCapturePhase.permissionDenied
              : PreJoinCapturePhase.unavailable,
          error: error,
        ),
      );
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to create local video track',
      );
    }
  }

  Future<LocalAudioTrack?> _initializeMicrophone() async {
    await _disposeMicrophoneTrack();
    if (!ref.mounted || !state.preferences.isMicOn) return null;

    _setMicrophone(
      const PreJoinCaptureState(phase: PreJoinCapturePhase.initializing),
    );
    LocalAudioTrack? track;
    try {
      track = await ref
          .read(preJoinPreviewTrackFactoryProvider)
          .createAudioTrack();
      if (!ref.mounted) {
        await _disposeTrack(track, 'microphone');
        return null;
      }
      if (!state.preferences.isMicOn) {
        await _disposeTrack(track, 'microphone');
        _setMicrophone(
          const PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
        );
        return null;
      }
      await track?.enable();
      await track?.start();
      if (!ref.mounted || !state.preferences.isMicOn) {
        await _disposeTrack(track, 'microphone');
        if (ref.mounted) {
          _setMicrophone(
            const PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
          );
        }
        return null;
      }
      if (track == null) {
        state = state.copyWith(
          preferences: state.preferences.copyWith(isMicOn: false),
          microphone: const PreJoinCaptureState(
            phase: PreJoinCapturePhase.unavailable,
          ),
        );
        return null;
      }
      _setMicrophone(
        PreJoinCaptureState(
          phase: PreJoinCapturePhase.ready,
          track: track,
        ),
      );
      _microphoneTrack = track;
      _observeUnexpectedTrackEnd(track, isCamera: false);
      return track;
    } catch (error, stackTrace) {
      await _disposeTrack(track, 'microphone');
      if (!ref.mounted) return null;
      state = state.copyWith(
        preferences: state.preferences.copyWith(isMicOn: false),
        microphone: PreJoinCaptureState(
          phase: _isWebMediaPermissionDenied(error)
              ? PreJoinCapturePhase.permissionDenied
              : PreJoinCapturePhase.unavailable,
          error: error,
        ),
      );
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to create local audio track',
      );
      return null;
    }
  }

  Future<void> toggleCamera() async {
    if (_togglingCamera || state.transferred) return;
    _togglingCamera = true;
    try {
      if (state.preferences.isCameraOn) {
        final track = _cameraTrack;
        _cameraTrack = null;
        state = state.copyWith(
          preferences: state.preferences.copyWith(isCameraOn: false),
          camera: const PreJoinCaptureState(
            phase: PreJoinCapturePhase.disabled,
          ),
        );
        await _captureOperations.schedule(
          () => identical(track, _transferredVideoTrack)
              ? Future<void>.value()
              : _disposeTrack(track, 'camera'),
        );
      } else {
        state = state.copyWith(
          preferences: state.preferences.copyWith(isCameraOn: true),
        );
        await _captureOperations.schedule(_initializeCamera);
      }
    } finally {
      _togglingCamera = false;
    }
  }

  Future<void> toggleMicrophone() async {
    if (_togglingMicrophone || state.transferred) return;
    _togglingMicrophone = true;
    try {
      if (state.preferences.isMicOn) {
        final track = _microphoneTrack;
        _microphoneTrack = null;
        state = state.copyWith(
          preferences: state.preferences.copyWith(isMicOn: false),
          microphone: const PreJoinCaptureState(
            phase: PreJoinCapturePhase.disabled,
          ),
        );
        await _captureOperations.schedule(
          () => identical(track, _transferredAudioTrack)
              ? Future<void>.value()
              : _disposeTrack(track, 'microphone'),
        );
      } else {
        state = state.copyWith(
          preferences: state.preferences.copyWith(isMicOn: true),
        );
        await _captureOperations.schedule(() async {
          final track = await _initializeMicrophone();
          await track?.unmute(stopOnMute: false);
        });
      }
    } finally {
      _togglingMicrophone = false;
    }
  }

  void toggleSpeaker() {
    if (state.transferred) return;
    state = state.copyWith(
      preferences: state.preferences.copyWith(
        isSpeakerOn: !state.preferences.isSpeakerOn,
      ),
    );
  }

  void setCameraPosition(CameraPosition position) {
    _setCameraOptions(
      state.preferences.cameraOptions.copyWith(cameraPosition: position),
    );
  }

  void selectCameraDevice(MediaDevice device) {
    _setCameraOptions(
      state.preferences.cameraOptions.copyWith(deviceId: device.deviceId),
    );
  }

  void _setCameraOptions(CameraCaptureOptions options) {
    if (state.transferred) return;
    state = state.copyWith(
      preferences: state.preferences.copyWith(cameraOptions: options),
    );
    if (state.preferences.isCameraOn) {
      unawaited(_captureOperations.schedule(_initializeCamera));
    }
  }

  Future<PreJoinMediaState> retryFailedMedia() async {
    await _initialization;
    if (state.transferred) return state;

    Future<void> retry() async {
      if (state.camera.phase == PreJoinCapturePhase.unavailable ||
          state.camera.phase == PreJoinCapturePhase.permissionDenied) {
        state = state.copyWith(
          preferences: state.preferences.copyWith(isCameraOn: true),
        );
        await _captureOperations.schedule(_initializeCamera);
      }
      if (state.microphone.phase == PreJoinCapturePhase.unavailable ||
          state.microphone.phase == PreJoinCapturePhase.permissionDenied) {
        state = state.copyWith(
          preferences: state.preferences.copyWith(isMicOn: true),
        );
        await _captureOperations.schedule(_initializeMicrophone);
      }
    }

    _initialization = retry();
    await _initialization;
    return state;
  }

  Future<PreJoinMediaState> resetAfterFailedJoin() async {
    detachTransferredTracks();
    await _initialization;
    await _captureOperations.pending;

    // Failed-room teardown owned the transferred tracks. Clear the handoff
    // markers after teardown, then acquire one fresh capture pair.
    _transferredVideoTrack = null;
    _transferredAudioTrack = null;
    _cameraTrack = null;
    _microphoneTrack = null;
    state = PreJoinMediaState(
      preferences: state.preferences,
      camera: PreJoinCaptureState(
        phase: state.preferences.isCameraOn
            ? PreJoinCapturePhase.uninitialized
            : PreJoinCapturePhase.disabled,
      ),
      microphone: PreJoinCaptureState(
        phase: state.preferences.isMicOn
            ? PreJoinCapturePhase.uninitialized
            : PreJoinCapturePhase.disabled,
      ),
    );
    _initialization = initialize();
    await _initialization;
    return state;
  }

  /// Removes transferred tracks from the render state without disposing them.
  ///
  /// The Session owns these tracks after [takeForJoin]. Detaching synchronously
  /// lets it stop failed media without a renderer observing that teardown.
  void detachTransferredTracks() {
    if (!ref.mounted || !state.transferred) return;

    _cameraTrack = null;
    _microphoneTrack = null;
    state = state.copyWith(
      camera: PreJoinCaptureState(
        phase: state.preferences.isCameraOn
            ? PreJoinCapturePhase.uninitialized
            : PreJoinCapturePhase.disabled,
      ),
      microphone: PreJoinCaptureState(
        phase: state.preferences.isMicOn
            ? PreJoinCapturePhase.uninitialized
            : PreJoinCapturePhase.disabled,
      ),
    );
  }

  Future<SessionJoinMedia> takeForJoin() async {
    if (state.transferred) {
      throw StateError('Pre-join media has already been transferred');
    }
    await _initialization;
    await _captureOperations.pending;
    if (!state.canJoinOnWeb) {
      throw const PreJoinMediaPermissionDeniedException();
    }

    final cameraTrack = state.preferences.isCameraOn && state.camera.isReady
        ? state.camera.track
        : null;
    final microphoneTrack =
        state.preferences.isMicOn && state.microphone.isReady
        ? state.microphone.track
        : null;
    _transferredVideoTrack = cameraTrack;
    _transferredAudioTrack = microphoneTrack;
    state = state.copyWith(transferred: true);
    return SessionJoinMedia(
      cameraTrack: cameraTrack,
      microphoneTrack: microphoneTrack,
      onBeforeDispose: detachTransferredTracks,
    );
  }

  void _setCamera(PreJoinCaptureState<LocalVideoTrack> camera) {
    if (ref.mounted) state = state.copyWith(camera: camera);
  }

  void _setMicrophone(PreJoinCaptureState<LocalAudioTrack> microphone) {
    if (ref.mounted) state = state.copyWith(microphone: microphone);
  }

  void _observeUnexpectedTrackEnd(LocalTrack track, {required bool isCamera}) {
    try {
      final mediaStreamTrack = track.mediaStreamTrack;
      final liveKitOnEnded = mediaStreamTrack.onEnded;
      mediaStreamTrack.onEnded = () {
        liveKitOnEnded?.call();
        _handleUnexpectedTrackEnd(track, isCamera: isCamera);
      };
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to observe pre-join media track state',
      );
    }
  }

  void _handleUnexpectedTrackEnd(LocalTrack track, {required bool isCamera}) {
    if (!ref.mounted || state.transferred) return;

    if (isCamera) {
      if (!identical(_cameraTrack, track) || !state.preferences.isCameraOn) {
        return;
      }
      _cameraTrack = null;
      state = state.copyWith(
        preferences: state.preferences.copyWith(isCameraOn: false),
        camera: const PreJoinCaptureState(
          phase: PreJoinCapturePhase.permissionDenied,
        ),
      );
    } else {
      if (!identical(_microphoneTrack, track) || !state.preferences.isMicOn) {
        return;
      }
      _microphoneTrack = null;
      state = state.copyWith(
        preferences: state.preferences.copyWith(isMicOn: false),
        microphone: const PreJoinCaptureState(
          phase: PreJoinCapturePhase.permissionDenied,
        ),
      );
    }

    // The browser has already ended capture. Dispose the LiveKit wrapper on
    // the same queue as every other media operation without delaying the state
    // update that disables Join.
    unawaited(
      _captureOperations.schedule(
        () => _disposeTrack(track, isCamera ? 'camera' : 'microphone'),
      ),
    );
  }

  Future<void> _disposeCameraTrack() async {
    final track = _cameraTrack;
    if (identical(track, _transferredVideoTrack)) return;
    _cameraTrack = null;
    if (track != null) await _disposeTrack(track, 'camera');
  }

  Future<void> _disposeMicrophoneTrack() async {
    final track = _microphoneTrack;
    if (identical(track, _transferredAudioTrack)) return;
    _microphoneTrack = null;
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

bool _isWebMediaPermissionDenied(Object? error) {
  if (error == null) return false;
  final description = switch (error) {
    TrackCreateException(:final message) => message.toLowerCase(),
    _ => error.toString().toLowerCase(),
  };
  return description.contains('notallowederror') ||
      description.contains('permissiondeniederror') ||
      description.contains('permissiondismissederror') ||
      description.contains('permission denied') ||
      description.contains('securityerror');
}
