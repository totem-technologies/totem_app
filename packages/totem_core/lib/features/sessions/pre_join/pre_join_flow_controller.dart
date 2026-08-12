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

      final mediaController = ref.read(
        preJoinMediaControllerProvider(sessionSlug).notifier,
      );
      final currentMedia = ref.read(
        preJoinMediaControllerProvider(sessionSlug),
      );
      final requireUsableMedia = ref.read(
        preJoinRequiresUsableMediaProvider,
      );
      if (requireUsableMedia && !currentMedia.canJoinOnWeb) {
        state = state.copyWith(phase: PreJoinFlowPhase.idle);
        return PreJoinJoinOutcome.permissionsDenied;
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
      final joinMedia = await mediaController.takeForJoin(
        requireUsableMedia: requireUsableMedia,
      );
      mediaTransferred = true;

      final result = await currentSession.join(joinMedia: joinMedia);
      if (result == SessionJoinResult.retryableFailure) {
        await _resetAfterFailedJoin(currentSession);
        return PreJoinJoinOutcome.retryableFailure;
      }

      // Fatal failures are rendered by the session error UI, as before.
      state = state.copyWith(phase: PreJoinFlowPhase.joined);
      return PreJoinJoinOutcome.joined;
    } on PreJoinMediaPermissionDeniedException {
      if (ref.mounted) {
        state = state.copyWith(
          phase: PreJoinFlowPhase.idle,
          clearSessionOptions: true,
        );
      }
      return PreJoinJoinOutcome.permissionsDenied;
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
