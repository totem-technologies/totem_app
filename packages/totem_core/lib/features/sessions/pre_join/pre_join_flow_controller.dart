import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:livekit_client/livekit_client.dart' hide SessionOptions;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:totem_core/auth/controllers/auth_controller.dart';

import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/policy.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

part 'pre_join_flow_controller.g.dart';

@riverpod
class PreJoinFlowController extends _$PreJoinFlowController {
  @override
  PreJoinFlowState build(String sessionSlug) {
    ref.onDispose(() {
      _cancelRequested = true;
      unawaited(() async {
        try {
          await _admissionSetup;
        } catch (_) {
          // The request handles setup errors; disposal still owns the room.
        } finally {
          try {
            await _admission?.cancel();
          } finally {
            await _cleanupAdmission();
          }
        }
      }());
    });
    return const PreJoinFlowState();
  }

  Room? _admissionRoom;
  LiveKitAdmissionTransport? _admissionTransport;
  PendingAdmissionController? _admission;
  // ignore: cancel_subscriptions
  StreamSubscription<AdmissionStatus>? _admissionSubscription;
  Future<void>? _admissionSetup;
  Future<void>? _admissionCleanup;
  bool _cancelRequested = false;
  int _admissionAttempt = 0;

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
  LiveKitAdmissionTransport createAdmissionTransport(Room room) =>
      LiveKitAdmissionTransport(room);

  @visibleForTesting
  Future<void> connectAdmissionRoom(Room room, String token) => room.connect(
    AppConfig.instance.liveKitUrl,
    token,
    connectOptions: LiveKitAdmissionTransport.pendingConnectOptions,
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
      clearExpiresAt: true,
    );
    _cancelRequested = false;

    try {
      final response = await ref.refresh(
        sessionTokenProvider(sessionSlug).future,
      );
      if (!ref.mounted || _cancelRequested) return PreJoinJoinOutcome.ignored;
      if (response.isAlreadyPresent &&
          sessionSlug.isNotEmpty &&
          !replaceExistingSession) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle);
        return PreJoinJoinOutcome.confirmationRequired;
      }

      final readiness = await _currentJoinReadiness();
      if (!ref.mounted || _cancelRequested) return PreJoinJoinOutcome.ignored;
      if (readiness != JoinReadiness.ready) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle);
        return PreJoinJoinOutcome.microphoneNeeded;
      }

      final event = await ref.read(sessionProvider(sessionSlug).future);
      if (!ref.mounted || _cancelRequested) return PreJoinJoinOutcome.ignored;
      final user = ref.read(authControllerProvider).user;
      final keeper = event.space.author.slug.value;
      if (keeper == null || keeper.isEmpty) {
        throw StateError('Session keeper is unavailable');
      }
      if (keeper != user?.slug.value) {
        final displayName = user?.name.value?.trim();
        final name = displayName == null || displayName.isEmpty
            ? user?.slug.value
            : displayName;
        if (name == null || name.isEmpty) {
          throw StateError('A signed-in user is required for admission');
        }
        _admissionSetup = _startAdmission(response.token, keeper, name);
        await _admissionSetup;
        if (!ref.mounted || _cancelRequested) return PreJoinJoinOutcome.ignored;
        final admission = _admission;
        if (admission == null) return PreJoinJoinOutcome.ignored;
        if (admission.status == AdmissionStatus.ended ||
            admission.status == AdmissionStatus.failed) {
          await _handleAdmissionStatus(
            admission.status,
            response.token,
            _admissionAttempt,
            admission,
          );
          return PreJoinJoinOutcome.ignored;
        }
        return PreJoinJoinOutcome.pending;
      }
      return await _joinWithToken(response.token);
    } catch (error, stackTrace) {
      try {
        await _cleanupAdmission();
      } catch (cleanupError, cleanupStackTrace) {
        ErrorHandler.logError(
          cleanupError,
          stackTrace: cleanupStackTrace,
          message: 'Failed to close admission room',
        );
      }
      if (ref.mounted && isTerminalSessionJoinError(error)) {
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
      if (ref.mounted) {
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

  Future<void> _startAdmission(String token, String keeper, String name) async {
    final attempt = ++_admissionAttempt;
    final room = createAdmissionRoom();
    _admissionRoom = room;
    final transport = createAdmissionTransport(room);
    _admissionTransport = transport;
    final connectTrace = developer.TimelineTask()
      ..start('session_admission_room_connect');
    try {
      await connectAdmissionRoom(room, token);
    } finally {
      connectTrace.finish();
    }
    if (!ref.mounted || _cancelRequested) return;
    final admission = PendingAdmissionController(
      channel: transport,
      keeperIdentity: () => keeper,
    );
    _admission = admission;
    _admissionSubscription = admission.changes.listen((status) {
      if (status != AdmissionStatus.pending) {
        unawaited(_handleAdmissionStatus(status, token, attempt, admission));
      }
    });
    if (admission.status == AdmissionStatus.ended) return;
    final request = await admission.requestAdmission(displayName: name);
    if (!ref.mounted || _cancelRequested) return;
    if (admission.status == AdmissionStatus.pending) {
      state = state.copyWith(
        phase: PreJoinFlowPhase.pending,
        admissionStatus: AdmissionStatus.pending,
        expiresAt: request.expiresAt,
      );
    }
  }

  Future<void> _handleAdmissionStatus(
    AdmissionStatus status,
    String token,
    int attempt,
    PendingAdmissionController admission,
  ) async {
    try {
      await _admissionSetup;
    } catch (_) {
      // The request handles setup errors; no decision can be applied.
      return;
    }
    if (!ref.mounted ||
        _cancelRequested ||
        attempt != _admissionAttempt ||
        !identical(_admission, admission) ||
        admission.status != status) {
      return;
    }
    try {
      if (status == AdmissionStatus.approved) {
        final request = admission.request;
        if (request == null) return;
        state = state.copyWith(
          phase: PreJoinFlowPhase.joining,
          admissionStatus: status,
          clearExpiresAt: true,
        );
        final connectedRoom = await _takeAdmissionRoom();
        if (connectedRoom == null) return;
        if (ref.mounted && !_cancelRequested && attempt == _admissionAttempt) {
          try {
            await _joinWithToken(
              token,
              admissionRequest: request,
              admissionRoom: connectedRoom,
            );
          } catch (error, stackTrace) {
            if (ref.mounted &&
                attempt == _admissionAttempt &&
                isTerminalSessionJoinError(error)) {
              try {
                await ref
                    .read(preJoinMediaControllerProvider(sessionSlug).notifier)
                    .releaseForTerminalOutcome();
              } catch (releaseError, releaseStackTrace) {
                ErrorHandler.logError(
                  releaseError,
                  stackTrace: releaseStackTrace,
                  message:
                      'Failed to release preview after terminal join error',
                );
              }
            }
            if (ref.mounted && attempt == _admissionAttempt) {
              state = state.copyWith(
                phase: PreJoinFlowPhase.idle,
                error: error,
                clearSessionOptions: true,
              );
            }
            if (!isTerminalSessionJoinError(error)) {
              ErrorHandler.logError(
                error,
                stackTrace: stackTrace,
                message: 'Approved Session join was refused',
              );
            }
          }
        } else {
          await connectedRoom.disconnect();
          await connectedRoom.dispose();
        }
      } else if (status == AdmissionStatus.denied ||
          status == AdmissionStatus.expired ||
          status == AdmissionStatus.ended) {
        try {
          await _cleanupAdmission();
        } finally {
          if (ref.mounted && attempt == _admissionAttempt) {
            await ref
                .read(preJoinMediaControllerProvider(sessionSlug).notifier)
                .releaseForTerminalOutcome();
          }
        }
        if (ref.mounted && attempt == _admissionAttempt) {
          state = state.copyWith(
            phase: PreJoinFlowPhase.idle,
            admissionStatus: status,
            clearExpiresAt: true,
          );
        }
      } else if (status == AdmissionStatus.failed) {
        await _cleanupAdmission();
        if (ref.mounted && attempt == _admissionAttempt) {
          state = state.copyWith(
            phase: PreJoinFlowPhase.idle,
            admissionStatus: status,
            clearExpiresAt: true,
            error: StateError(
              'Waiting room connection was lost. Check your connection and try again.',
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      if (ref.mounted && attempt == _admissionAttempt) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          error: error,
          clearExpiresAt: true,
          admissionStatus:
              status == AdmissionStatus.denied ||
                  status == AdmissionStatus.expired ||
                  status == AdmissionStatus.ended ||
                  status == AdmissionStatus.failed
              ? status
              : null,
        );
      }
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to close admission room',
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
    try {
      await _admissionSetup;
      try {
        await _admission?.cancel();
      } finally {
        await _cleanupAdmission();
      }
      if (ref.mounted) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          admissionStatus: AdmissionStatus.cancelled,
          clearExpiresAt: true,
        );
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          error: error,
          clearExpiresAt: true,
        );
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
      await room.disconnect();
      await room.dispose();
      rethrow;
    }
  }

  Future<void> _disposeAdmission() async {
    final subscription = _admissionSubscription;
    final admission = _admission;
    final transport = _admissionTransport;
    final room = _admissionRoom;
    _admissionSubscription = null;
    _admission = null;
    _admissionTransport = null;
    _admissionRoom = null;
    try {
      await subscription?.cancel();
      await admission?.dispose();
    } finally {
      try {
        await transport?.dispose();
      } finally {
        try {
          await room?.disconnect();
        } finally {
          await room?.dispose();
        }
      }
    }
  }

  Future<JoinReadiness> _currentJoinReadiness() async {
    await ref
        .read(preJoinMediaControllerProvider(sessionSlug).notifier)
        .settled();
    if (!ref.mounted || _cancelRequested) return JoinReadiness.checking;
    final media = ref.read(preJoinMediaControllerProvider(sessionSlug));
    return joinReadiness(
      permissions: ref.read(mediaPermissionControllerProvider),
      microphoneProblem: media.microphone.problem,
      mediaSettled: media.initializationComplete,
    );
  }

  Future<PreJoinJoinOutcome> _joinWithToken(
    String token, {
    AdmissionRequest? admissionRequest,
    Room? admissionRoom,
  }) async {
    if (!ref.mounted || _cancelRequested) {
      await admissionRoom?.disconnect();
      await admissionRoom?.dispose();
      return PreJoinJoinOutcome.ignored;
    }
    var roomTransferred = false;
    SessionController? session;
    SessionJoinMedia? joinMedia;
    var joinStarted = false;
    var mediaTransferred = false;
    try {
      final mediaController = ref.read(
        preJoinMediaControllerProvider(sessionSlug).notifier,
      );

      // Precache before transferring preview tracks so failure is retryable.
      await ref.read(sessionProvider(sessionSlug).future);
      if (!ref.mounted || _cancelRequested) return PreJoinJoinOutcome.ignored;

      // Permissions or the preview may have changed while waiting for the Keeper.
      final readiness = await _currentJoinReadiness();
      if (!ref.mounted || _cancelRequested) return PreJoinJoinOutcome.ignored;
      if (readiness != JoinReadiness.ready) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          error: admissionRequest == null
              ? null
              : StateError(
                  'Microphone access changed after approval. Please try joining again.',
                ),
        );
        return PreJoinJoinOutcome.microphoneNeeded;
      }

      joinMedia = await mediaController.takeForJoin();
      mediaTransferred = true;
      if (!ref.mounted || _cancelRequested) {
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
      final currentSession = ref.read(
        sessionControllerProvider(options).notifier,
      );
      session = currentSession;
      currentSession.preventAutoDispose();

      joinStarted = true;
      final SessionJoinResult result;
      if (admissionRoom == null) {
        result = await currentSession.join(joinMedia: joinMedia);
      } else {
        roomTransferred = true;
        final activationTrace = developer.TimelineTask()
          ..start('session_admission_room_activation');
        try {
          result = await currentSession.activateConnectedRoom(
            room: admissionRoom,
            joinMedia: joinMedia,
          );
        } finally {
          activationTrace.finish();
        }
      }
      if (result == SessionJoinResult.retryableFailure ||
          (admissionRequest != null &&
              result == SessionJoinResult.fatalFailure)) {
        await _resetAfterFailedJoin(currentSession);
        if (ref.mounted && result == SessionJoinResult.fatalFailure) {
          state = state.copyWith(
            error: StateError('Failed to join the approved session'),
          );
        }
        return PreJoinJoinOutcome.retryableFailure;
      }

      // Keep the Keeper's existing fatal-error screen behavior. The connected
      // Session is ready; a pending data-channel send must not keep the local
      // user on pre-join after the Keeper has already processed the receipt.
      if (ref.mounted) state = state.copyWith(phase: PreJoinFlowPhase.joined);
      if (admissionRequest != null && ref.mounted) {
        // The Keeper's roster still governs visibility to other participants.
        // Retain best-effort receipt recovery on presence and reconnect.
        unawaited(() async {
          try {
            await currentSession.messaging.sendAdmissionJoined(
              admissionRequest,
            );
          } catch (error, stackTrace) {
            ErrorHandler.logError(
              error,
              stackTrace: stackTrace,
              message: 'Could not confirm Session admission to Keeper',
            );
          }
        }());
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
        if (ref.mounted) {
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
          if (ref.mounted) {
            state = state.copyWith(
              phase: PreJoinFlowPhase.idle,
              clearSessionOptions: true,
            );
          }
        }
      } else if (mediaTransferred && session != null) {
        try {
          await _resetAfterFailedJoin(session);
        } catch (resetError, resetStackTrace) {
          ErrorHandler.logError(
            resetError,
            stackTrace: resetStackTrace,
            message: 'Failed to reset media after join failure',
          );
          if (ref.mounted) {
            state = state.copyWith(
              phase: PreJoinFlowPhase.idle,
              clearSessionOptions: true,
            );
          }
        }
      } else if (ref.mounted) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          clearSessionOptions: true,
        );
      }
      if (ref.mounted) state = state.copyWith(error: error);
      if (!isTerminalSessionJoinError(error)) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to join room',
        );
      }
      return PreJoinJoinOutcome.retryableFailure;
    } finally {
      session?.allowAutoDispose();
      if (admissionRoom != null && !roomTransferred) {
        await admissionRoom.disconnect();
        await admissionRoom.dispose();
      }
    }
  }

  Future<void> _resetAfterFailedJoin(SessionController session) async {
    // Detach renderers first, then let LiveKit release the transferred capture.
    // Fresh tracks must still wait for teardown to avoid Safari dual-capture.
    ref
        .read(preJoinMediaControllerProvider(sessionSlug).notifier)
        .detachTransferredTracks();
    await session.resetAfterFailedJoin();
    if (!ref.mounted) return;
    await ref
        .read(preJoinMediaControllerProvider(sessionSlug).notifier)
        .resetAfterFailedJoin();
    if (ref.mounted) {
      state = state.copyWith(
        phase: PreJoinFlowPhase.idle,
        clearSessionOptions: true,
      );
    }
  }
}
