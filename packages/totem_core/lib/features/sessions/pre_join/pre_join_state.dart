import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide SessionOptions;
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

enum PreJoinCapturePhase {
  uninitialized,
  initializing,
  ready,
  disabled,
  unavailable,
  permissionDenied,
}

enum PreJoinFlowPhase { idle, joining, joined }

enum PreJoinJoinOutcome {
  confirmationRequired,
  joined,
  retryableFailure,
  ignored,
}

@immutable
class PreJoinMediaPreferences {
  const PreJoinMediaPreferences({
    this.isSpeakerOn = true,
    this.isCameraOn = true,
    this.isMicOn = true,
    this.cameraOptions = SessionController.defaultCameraCaptureOptions,
  });

  final bool isSpeakerOn;
  final bool isCameraOn;
  final bool isMicOn;
  final CameraCaptureOptions cameraOptions;

  PreJoinMediaPreferences copyWith({
    bool? isSpeakerOn,
    bool? isCameraOn,
    bool? isMicOn,
    CameraCaptureOptions? cameraOptions,
  }) {
    return PreJoinMediaPreferences(
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isMicOn: isMicOn ?? this.isMicOn,
      cameraOptions: cameraOptions ?? this.cameraOptions,
    );
  }
}

@immutable
class PreJoinCaptureState<T extends LocalTrack> {
  const PreJoinCaptureState({
    required this.phase,
    this.track,
    this.error,
  });

  const PreJoinCaptureState.uninitialized()
    : phase = PreJoinCapturePhase.uninitialized,
      track = null,
      error = null;

  final PreJoinCapturePhase phase;
  final T? track;
  final Object? error;

  bool get initializationComplete => switch (phase) {
    PreJoinCapturePhase.uninitialized ||
    PreJoinCapturePhase.initializing => false,
    _ => true,
  };

  bool get isReady => phase == PreJoinCapturePhase.ready && track != null;
}

@immutable
class PreJoinMediaState {
  const PreJoinMediaState({
    this.preferences = const PreJoinMediaPreferences(),
    this.camera = const PreJoinCaptureState<LocalVideoTrack>.uninitialized(),
    this.microphone =
        const PreJoinCaptureState<LocalAudioTrack>.uninitialized(),
    this.transferred = false,
  });

  final PreJoinMediaPreferences preferences;
  final PreJoinCaptureState<LocalVideoTrack> camera;
  final PreJoinCaptureState<LocalAudioTrack> microphone;
  final bool transferred;

  bool get initializationComplete =>
      camera.initializationComplete && microphone.initializationComplete;

  bool get canJoinOnWeb =>
      initializationComplete &&
      (microphone.phase == PreJoinCapturePhase.ready ||
          microphone.phase == PreJoinCapturePhase.disabled) &&
      (camera.phase == PreJoinCapturePhase.ready ||
          camera.phase == PreJoinCapturePhase.disabled ||
          camera.phase == PreJoinCapturePhase.unavailable);

  PreJoinMediaState copyWith({
    PreJoinMediaPreferences? preferences,
    PreJoinCaptureState<LocalVideoTrack>? camera,
    PreJoinCaptureState<LocalAudioTrack>? microphone,
    bool? transferred,
  }) {
    return PreJoinMediaState(
      preferences: preferences ?? this.preferences,
      camera: camera ?? this.camera,
      microphone: microphone ?? this.microphone,
      transferred: transferred ?? this.transferred,
    );
  }
}

@immutable
class PreJoinFlowState {
  const PreJoinFlowState({
    this.phase = PreJoinFlowPhase.idle,
    this.sessionOptions,
    this.nativePermissionsGranted = false,
  });

  final PreJoinFlowPhase phase;
  final SessionOptions? sessionOptions;
  final bool nativePermissionsGranted;

  PreJoinFlowState copyWith({
    PreJoinFlowPhase? phase,
    SessionOptions? sessionOptions,
    bool? nativePermissionsGranted,
  }) {
    return PreJoinFlowState(
      phase: phase ?? this.phase,
      sessionOptions: sessionOptions ?? this.sessionOptions,
      nativePermissionsGranted:
          nativePermissionsGranted ?? this.nativePermissionsGranted,
    );
  }
}
