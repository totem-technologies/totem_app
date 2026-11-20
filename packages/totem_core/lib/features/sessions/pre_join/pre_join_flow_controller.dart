import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide SessionOptions;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart'
    show AdmissionJoinState, AdmissionJoinStatePermissions;
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/policy.dart';
import 'package:totem_core/features/sessions/admission/server_participant_admission.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/livekit_server_admission_connection.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/participant_admission_repository.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

part 'pre_join_flow_controller.g.dart';

@riverpod
class PreJoinFlowController extends _$PreJoinFlowController {
  @override
  PreJoinFlowState build(String sessionSlug) {
    ref.onDispose(() {
      _cancelRequested = true;
      ++_admissionAttempt;
      unawaited(() async {
        try {
          await _admissionSetup;
        } catch (_) {
          // The request handles setup errors; disposal still owns the room.
        } finally {
          try {
            await _serverAdmission?.cancel();
          } finally {
            await _cleanupAdmission();
          }
        }
      }());
    });
    return const PreJoinFlowState();
  }

  Room? _admissionRoom;
  ServerParticipantAdmission? _serverAdmission;
  StreamSubscription<AdmissionStatus>? _serverAdmissionSubscription;
  Future<void>? _admissionSetup;
  Future<void>? _admissionCleanup;
  bool _cancelRequested = false;
  int _admissionAttempt = 0;
  int? _handledAdmissionAttempt;

  bool _isCurrent(int attempt) =>
      ref.mounted && !_cancelRequested && attempt == _admissionAttempt;

  @visibleForTesting
  DateTime now() => DateTime.now();

  @visibleForTesting
  Room createAdmissionRoom() {
    final preferences = ref
        .read(preJoinMediaControllerProvider(sessionSlug))
        .preferences;
    return Room(
      roomOptions: SessionController.sessionRoomOptions(
        cameraOptions: preferences.cameraOptions,
        speakerEnabled: preferences.isSpeakerOn,
      ),
    );
  }

  @visibleForTesting
  Future<void> connectAdmissionRoom(Room room, String token) => room.connect(
    AppConfig.instance.liveKitUrl,
    token,
    connectOptions: const ConnectOptions(autoSubscribe: false),
  );

  Future<PreJoinJoinOutcome> requestJoin({
    bool replaceExistingSession = false,
  }) async {
    if (state.phase != PreJoinFlowPhase.idle ||
        state.admissionStatus == AdmissionStatus.denied ||
        state.admissionStatus == AdmissionStatus.expired ||
        state.admissionStatus == AdmissionStatus.ended ||
        isTerminalSessionJoinError(state.error)) {
      return PreJoinJoinOutcome.ignored;
    }

    state = state.copyWith(
      phase: PreJoinFlowPhase.joining,
      clearError: true,
      clearAdmissionStatus: true,
      keeperAvailability: AdmissionKeeperAvailability.checking,
    );
    _cancelRequested = false;
    final attempt = ++_admissionAttempt;
    _admissionSetup = null;

    try {
      final response = await ref.refresh(
        sessionTokenProvider(sessionSlug).future,
      );
      if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;
      if (response.isAlreadyPresent &&
          sessionSlug.isNotEmpty &&
          !replaceExistingSession) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle);
        return PreJoinJoinOutcome.confirmationRequired;
      }

      final readiness = await _currentJoinReadiness(attempt);
      if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;
      if (readiness != JoinReadiness.ready) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle);
        return PreJoinJoinOutcome.microphoneNeeded;
      }

      final serverState = response.admission.isPresent
          ? response.admission.value
          : null;
      if (serverState == null ||
          serverState.permissions.isUnknown ||
          ServerAdmissionAttemptStatus.parse(
                serverState.status,
              )?.isAllowedJoinResponse !=
              true ||
          serverState.requestId.isEmpty ||
          serverState.attemptId.isEmpty) {
        throw StateError('Server admission is unavailable or unsupported');
      }
      _admissionSetup = _startServerAdmission(
        response.token,
        serverState,
        attempt,
      );
      await _admissionSetup;
      if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;
      final admission = _serverAdmission;
      if (admission == null) return PreJoinJoinOutcome.ignored;
      if (admission.status != AdmissionStatus.pending) {
        unawaited(
          _handleServerAdmissionStatus(
            admission.status,
            response.token,
            attempt,
            admission,
          ),
        );
      }
      return PreJoinJoinOutcome.pending;
    } catch (error, stackTrace) {
      if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;
      try {
        await _cleanupAdmission();
      } catch (cleanupError, cleanupStackTrace) {
        ErrorHandler.logError(
          cleanupError,
          stackTrace: cleanupStackTrace,
          message: 'Failed to close admission room',
        );
      }
      if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;
      if (isTerminalSessionJoinError(error)) {
        try {
          await ref
              .read(preJoinMediaControllerProvider(sessionSlug).notifier)
              .releaseForTerminalOutcome();
        } catch (releaseError, releaseStackTrace) {
          ErrorHandler.logError(
            releaseError,
            stackTrace: releaseStackTrace,
            message: 'Failed to release preview after terminal join error',
          );
        }
      }
      if (_isCurrent(attempt)) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          clearSessionOptions: true,
          error: error,
        );
      }
      if (!isTerminalSessionJoinError(error)) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to request session admission',
        );
      }
      return PreJoinJoinOutcome.retryableFailure;
    }
  }

  @visibleForTesting
  ServerParticipantAdmission createServerAdmission(
    Room room,
    AdmissionJoinState initial,
  ) => ServerParticipantAdmission(
    repository: ref.read(participantAdmissionRepositoryProvider),
    sessionSlug: sessionSlug,
    initial: initial,
    connection: LiveKitServerAdmissionConnection(room),
    now: now,
  );

  Future<void> _startServerAdmission(
    String token,
    AdmissionJoinState initial,
    int attempt,
  ) async {
    if (!_isCurrent(attempt)) return;
    final room = createAdmissionRoom();
    _admissionRoom = room;
    final admission = createServerAdmission(room, initial);
    final pendingPhase =
        initial.permissions == AdmissionJoinStatePermissions.waiting
        ? PreJoinFlowPhase.pending
        : PreJoinFlowPhase.joining;
    _serverAdmission = admission;
    _serverAdmissionSubscription = admission.changes.listen((status) {
      if (status == AdmissionStatus.pending) {
        if (_isCurrent(attempt)) {
          state = state.copyWith(
            phase: pendingPhase,
            admissionStatus: status,
            keeperAvailability: admission.keeperAvailability,
          );
        }
      } else {
        unawaited(
          _handleServerAdmissionStatus(status, token, attempt, admission),
        );
      }
    });
    final trace = developer.TimelineTask()
      ..start('session_admission_room_connect');
    try {
      await connectAdmissionRoom(room, token);
    } finally {
      trace.finish();
    }
    if (!_isCurrent(attempt)) return;
    await admission.start();
    if (_isCurrent(attempt) && admission.status == AdmissionStatus.pending) {
      state = state.copyWith(
        phase: pendingPhase,
        admissionStatus: AdmissionStatus.pending,
        keeperAvailability: admission.keeperAvailability,
      );
    }
  }

  Future<void> _handleServerAdmissionStatus(
    AdmissionStatus status,
    String token,
    int attempt,
    ServerParticipantAdmission admission,
  ) async {
    try {
      await _admissionSetup;
    } catch (_) {
      return;
    }
    if (!_isCurrent(attempt) ||
        !identical(_serverAdmission, admission) ||
        admission.status != status ||
        _handledAdmissionAttempt == attempt) {
      return;
    }
    _handledAdmissionAttempt = attempt;
    try {
      if (status == AdmissionStatus.approved) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.joining,
          admissionStatus: status,
          isReturningParticipant: admission.isReturningParticipant,
          sessionStartedAtAdmission: admission.sessionStartedAtAdmission,
        );
        await _serverAdmissionSubscription?.cancel();
        if (!_isCurrent(attempt) || !identical(_serverAdmission, admission)) {
          return;
        }
        _serverAdmissionSubscription = null;
        _serverAdmission = null;
        final room = await _takeAdmissionRoom();
        if (room == null) {
          await admission.dispose();
          return;
        }
        if (!_isCurrent(attempt)) {
          await admission.dispose();
          await _closeAdmissionRoom(room);
          return;
        }
        await _joinWithToken(
          token,
          admissionRoom: room,
          serverAdmission: admission,
          attempt: attempt,
        );
        return;
      }
      if (status == AdmissionStatus.denied ||
          status == AdmissionStatus.expired ||
          status == AdmissionStatus.ended ||
          status == AdmissionStatus.cancelled ||
          status == AdmissionStatus.failed) {
        try {
          await _cleanupAdmission();
        } finally {
          if (_isCurrent(attempt) && status != AdmissionStatus.failed) {
            await ref
                .read(preJoinMediaControllerProvider(sessionSlug).notifier)
                .releaseForTerminalOutcome();
          }
        }
        if (_isCurrent(attempt)) {
          state = state.copyWith(
            phase: PreJoinFlowPhase.idle,
            admissionStatus: status,
            error: status == AdmissionStatus.failed ? admission.error : null,
          );
        }
      }
    } catch (error, stackTrace) {
      await admission.dispose();
      if (_isCurrent(attempt)) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle, error: error);
      }
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to handle server admission',
      );
    }
  }

  Future<void> cancelAdmission() async {
    if (state.phase == PreJoinFlowPhase.joined ||
        (state.phase == PreJoinFlowPhase.idle &&
            _admissionRoom == null &&
            _admissionCleanup == null)) {
      return;
    }
    _cancelRequested = true;
    final attempt = ++_admissionAttempt;
    final setup = _admissionSetup;
    try {
      try {
        await setup;
        if (attempt == _admissionAttempt) await _serverAdmission?.cancel();
      } finally {
        if (attempt == _admissionAttempt) await _cleanupAdmission();
      }
      if (ref.mounted && attempt == _admissionAttempt) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          admissionStatus: AdmissionStatus.cancelled,
        );
      }
    } catch (error, stackTrace) {
      if (ref.mounted && attempt == _admissionAttempt) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle, error: error);
      }
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to cancel admission',
      );
    }
  }

  Future<void> _cleanupAdmission() =>
      _admissionCleanup ??= _disposeAdmission().whenComplete(() {
        _admissionCleanup = null;
      });

  Future<Room?> _takeAdmissionRoom() async {
    final room = _admissionRoom;
    if (room == null) return null;
    _admissionRoom = null;
    try {
      await _cleanupAdmission();
      return room;
    } catch (_) {
      await _closeAdmissionRoom(room);
      rethrow;
    }
  }

  Future<void> _closeAdmissionRoom(Room room) async {
    try {
      await room.disconnect();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disconnect admission room',
      );
    }
    try {
      await room.dispose();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to dispose admission room',
      );
    }
  }

  Future<void> _disposeAdmission() async {
    final serverSubscription = _serverAdmissionSubscription;
    final serverAdmission = _serverAdmission;
    final room = _admissionRoom;
    _serverAdmissionSubscription = null;
    _serverAdmission = null;
    _admissionRoom = null;
    try {
      await serverSubscription?.cancel();
      await serverAdmission?.dispose();
    } finally {
      if (room != null) await _closeAdmissionRoom(room);
    }
  }

  Future<JoinReadiness> _currentJoinReadiness(int attempt) async {
    await ref
        .read(preJoinMediaControllerProvider(sessionSlug).notifier)
        .settled();
    if (!_isCurrent(attempt)) return JoinReadiness.checking;
    final media = ref.read(preJoinMediaControllerProvider(sessionSlug));
    return joinReadiness(
      permissions: ref.read(mediaPermissionControllerProvider),
      microphoneProblem: media.microphone.problem,
      mediaSettled: media.initializationComplete,
    );
  }

  Future<PreJoinJoinOutcome> _joinWithToken(
    String token, {
    required Room admissionRoom,
    required ServerParticipantAdmission serverAdmission,
    required int attempt,
  }) async {
    if (!_isCurrent(attempt)) {
      await serverAdmission.dispose();
      await _closeAdmissionRoom(admissionRoom);
      return PreJoinJoinOutcome.ignored;
    }
    var roomTransferred = false;
    SessionController? session;
    SessionJoinMedia? joinMedia;
    var joinStarted = false;
    var mediaTransferred = false;
    void Function()? releaseSessionListener;
    try {
      final mediaController = ref.read(
        preJoinMediaControllerProvider(sessionSlug).notifier,
      );

      // Precache before transferring preview tracks so failure is retryable.
      await ref.read(sessionProvider(sessionSlug).future);
      if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;

      // Permissions or the preview may have changed while waiting for the Keeper.
      final readiness = await _currentJoinReadiness(attempt);
      if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;
      if (readiness != JoinReadiness.ready) {
        if (!_isCurrent(attempt)) return PreJoinJoinOutcome.ignored;
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          error: StateError(
            'Microphone access changed after approval. Please try joining again.',
          ),
        );
        return PreJoinJoinOutcome.microphoneNeeded;
      }

      joinMedia = await mediaController.takeForJoin();
      mediaTransferred = true;
      if (!_isCurrent(attempt)) {
        throw StateError('Pre-join flow closed before media handoff');
      }

      // Capture preferences after media initialization has settled. A failed or
      // revoked pre-join capture clears its preference, so an earlier snapshot
      // would incorrectly create a new camera after joining.
      final preferences = ref
          .read(preJoinMediaControllerProvider(sessionSlug))
          .preferences;
      final options = SessionOptions(
        sessionSlug: sessionSlug,
        token: token,
        cameraEnabled: preferences.isCameraOn,
        microphoneEnabled: preferences.isMicOn,
        speakerEnabled: preferences.isSpeakerOn,
        cameraOptions: preferences.cameraOptions,
      );
      state = state.copyWith(sessionOptions: options);

      // The session is now ready, so the join screen can render without adding
      // another loading transition.
      final subscription = ref.listen(
        sessionControllerProvider(options),
        (_, _) {},
      );
      releaseSessionListener = subscription.close;
      final currentSession = ref.read(
        sessionControllerProvider(options).notifier,
      );
      session = currentSession;

      joinStarted = true;
      roomTransferred = true;
      final activationTrace = developer.TimelineTask()
        ..start('session_admission_room_activation');
      final SessionJoinResult result;
      try {
        result = await currentSession.activateConnectedRoom(
          room: admissionRoom,
          joinMedia: joinMedia,
          serverAdmission: serverAdmission,
        );
      } finally {
        activationTrace.finish();
      }
      if (!_isCurrent(attempt)) {
        await currentSession.resetAfterFailedJoin();
        return PreJoinJoinOutcome.ignored;
      }
      if (result == SessionJoinResult.retryableFailure ||
          result == SessionJoinResult.fatalFailure) {
        await _resetAfterFailedJoin(currentSession, attempt);
        if (_isCurrent(attempt) && result == SessionJoinResult.fatalFailure) {
          state = state.copyWith(
            error: StateError('Failed to join the approved session'),
          );
        }
        return PreJoinJoinOutcome.retryableFailure;
      }

      try {
        await serverAdmission.activate();
        if (serverAdmission.status != AdmissionStatus.approved) {
          throw StateError('Admission is no longer authorized');
        }
      } catch (error) {
        if (serverAdmission.status != AdmissionStatus.pending ||
            !identical(serverAdmission.error, error)) {
          rethrow;
        }
        // Admission owns retrying the receipt after reconfirmation.
      }
      if (!_isCurrent(attempt)) {
        await currentSession.resetAfterFailedJoin();
        return PreJoinJoinOutcome.ignored;
      }

      if (_isCurrent(attempt)) {
        state = state.copyWith(phase: PreJoinFlowPhase.joined);
        // Keep the session alive until this flow is disposed, including the
        // frame before the room screen subscribes to the session.
        releaseSessionListener = null;
      }
      return PreJoinJoinOutcome.joined;
    } catch (error, stackTrace) {
      if (mediaTransferred && !joinStarted && joinMedia != null) {
        try {
          joinMedia.onBeforeDispose?.call();
        } catch (detachError, detachStackTrace) {
          ErrorHandler.logError(
            detachError,
            stackTrace: detachStackTrace,
            message: 'Failed to detach unclaimed preview media',
          );
        }
        await JoinMediaOwner().retain(joinMedia).dispose();
        if (_isCurrent(attempt)) {
          try {
            await ref
                .read(preJoinMediaControllerProvider(sessionSlug).notifier)
                .resetAfterFailedJoin();
          } catch (resetError, resetStackTrace) {
            ErrorHandler.logError(
              resetError,
              stackTrace: resetStackTrace,
              message: 'Failed to reset media after join failure',
            );
          }
          if (_isCurrent(attempt)) {
            state = state.copyWith(
              phase: PreJoinFlowPhase.idle,
              clearSessionOptions: true,
            );
          }
        }
      } else if (mediaTransferred && session != null) {
        try {
          await _resetAfterFailedJoin(session, attempt);
        } catch (resetError, resetStackTrace) {
          ErrorHandler.logError(
            resetError,
            stackTrace: resetStackTrace,
            message: 'Failed to reset media after join failure',
          );
          if (_isCurrent(attempt)) {
            state = state.copyWith(
              phase: PreJoinFlowPhase.idle,
              clearSessionOptions: true,
            );
          }
        }
      } else if (_isCurrent(attempt)) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          clearSessionOptions: true,
        );
      }
      if (_isCurrent(attempt)) state = state.copyWith(error: error);
      if (!isTerminalSessionJoinError(error)) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to join room',
        );
      }
      return _isCurrent(attempt)
          ? PreJoinJoinOutcome.retryableFailure
          : PreJoinJoinOutcome.ignored;
    } finally {
      releaseSessionListener?.call();
      if (!roomTransferred) {
        await serverAdmission.dispose();
        await _closeAdmissionRoom(admissionRoom);
      }
    }
  }

  Future<void> _resetAfterFailedJoin(
    SessionController session,
    int attempt,
  ) async {
    if (!_isCurrent(attempt)) {
      await session.resetAfterFailedJoin();
      return;
    }
    // Detach renderers first, then let LiveKit release the transferred capture.
    // Fresh tracks must still wait for teardown to avoid Safari dual-capture.
    ref
        .read(preJoinMediaControllerProvider(sessionSlug).notifier)
        .detachTransferredTracks();
    await session.resetAfterFailedJoin();
    if (!_isCurrent(attempt)) return;
    await ref
        .read(preJoinMediaControllerProvider(sessionSlug).notifier)
        .resetAfterFailedJoin();
    if (_isCurrent(attempt)) {
      state = state.copyWith(
        phase: PreJoinFlowPhase.idle,
        clearSessionOptions: true,
      );
    }
  }
}
