import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide SessionOptions;
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

enum PreJoinCapturePhase {
  uninitialized,
  initializing,
  waitingForForeground,
  ready,
  disabled,
  unavailable,
  permissionDenied,
}

enum PreJoinFlowPhase { idle, joining, pending, joined }

enum PreJoinJoinOutcome {
  confirmationRequired,
  pending,
  joined,
  retryableFailure,
  permissionsDenied,
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
  const PreJoinCaptureState({required this.phase, this.track, this.error});

  const PreJoinCaptureState.uninitialized()
    : phase = PreJoinCapturePhase.uninitialized,
      track = null,
      error = null;

  final PreJoinCapturePhase phase;
  final T? track;
  final Object? error;

  bool get initializationComplete => switch (phase) {
    PreJoinCapturePhase.uninitialized ||
    PreJoinCapturePhase.initializing ||
    PreJoinCapturePhase.waitingForForeground => false,
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
    this.admissionStatus,
    this.expiresAt,
    this.error,
  });

  final PreJoinFlowPhase phase;
  final SessionOptions? sessionOptions;
  final bool nativePermissionsGranted;
  final AdmissionStatus? admissionStatus;
  final DateTime? expiresAt;
  final Object? error;

  PreJoinFlowState copyWith({
    PreJoinFlowPhase? phase,
    SessionOptions? sessionOptions,
    bool clearSessionOptions = false,
    bool? nativePermissionsGranted,
    AdmissionStatus? admissionStatus,
    bool clearAdmissionStatus = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    Object? error,
    bool clearError = false,
  }) {
    return PreJoinFlowState(
      phase: phase ?? this.phase,
      sessionOptions: clearSessionOptions
          ? null
          : sessionOptions ?? this.sessionOptions,
      nativePermissionsGranted:
          nativePermissionsGranted ?? this.nativePermissionsGranted,
      admissionStatus: clearAdmissionStatus
          ? null
          : admissionStatus ?? this.admissionStatus,
      expiresAt: clearExpiresAt ? null : expiresAt ?? this.expiresAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}
