import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

part 'pre_join_flow_controller.g.dart';

@riverpod
class PreJoinFlowController extends _$PreJoinFlowController {
  @override
  PreJoinFlowState build(String sessionSlug) => const PreJoinFlowState();

  void setNativePermissionsGranted(bool granted) {
    state = state.copyWith(nativePermissionsGranted: granted);
  }

  Future<PreJoinJoinOutcome> requestJoin({
    bool replaceExistingSession = false,
  }) async {
    if (state.phase != PreJoinFlowPhase.idle) {
      return PreJoinJoinOutcome.ignored;
    }

    state = state.copyWith(phase: PreJoinFlowPhase.joining);
    SessionController? session;
    var mediaTransferred = false;

    try {
      final response = await ref.read(sessionTokenProvider(sessionSlug).future);
      if (response.isAlreadyPresent &&
          sessionSlug.isNotEmpty &&
          !replaceExistingSession) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle);
        return PreJoinJoinOutcome.confirmationRequired;
      }

      final preferences = ref
          .read(preJoinMediaControllerProvider(sessionSlug))
          .preferences;
      final options = SessionOptions(
        eventSlug: sessionSlug,
        token: response.token,
        cameraEnabled: preferences.isCameraOn,
        microphoneEnabled: preferences.isMicOn,
        speakerEnabled: preferences.isSpeakerOn,
        cameraOptions: preferences.cameraOptions,
      );
      state = state.copyWith(sessionOptions: options);

      // Precache event data before connection so the session screen can render
      // without adding another loading transition.
      await ref.read(eventProvider(sessionSlug).future);

      final currentSession = ref.read(
        sessionControllerProvider(options).notifier,
      );
      session = currentSession;
      currentSession.preventAutoDispose();
      final joinMedia = await ref
          .read(preJoinMediaControllerProvider(sessionSlug).notifier)
          .takeForJoin();
      mediaTransferred = true;

      final result = await currentSession.join(joinMedia: joinMedia);
      if (result == SessionJoinResult.retryableFailure) {
        await _resetAfterFailedJoin(currentSession);
        return PreJoinJoinOutcome.retryableFailure;
      }

      // Fatal failures are rendered by the session error UI, as before.
      state = state.copyWith(phase: PreJoinFlowPhase.joined);
      return PreJoinJoinOutcome.joined;
    } catch (error, stackTrace) {
      if (mediaTransferred && session != null) {
        try {
          await _resetAfterFailedJoin(session);
        } catch (resetError, resetStackTrace) {
          ErrorHandler.logError(
            resetError,
            stackTrace: resetStackTrace,
            message: 'Failed to reset media after join failure',
          );
          if (ref.mounted) {
            state = state.copyWith(phase: PreJoinFlowPhase.idle);
          }
        }
      } else if (ref.mounted) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle);
      }
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to join room',
      );
      return PreJoinJoinOutcome.retryableFailure;
    } finally {
      session?.allowAutoDispose();
    }
  }

  Future<void> _resetAfterFailedJoin(SessionController session) async {
    // LiveKit must release transferred captures before the preview opens fresh
    // tracks. Reversing this order recreates Safari's dual-capture failure.
    await session.resetAfterFailedJoin();
    if (!ref.mounted) return;
    await ref
        .read(preJoinMediaControllerProvider(sessionSlug).notifier)
        .resetAfterFailedJoin();
    if (ref.mounted) state = state.copyWith(phase: PreJoinFlowPhase.idle);
  }
}
