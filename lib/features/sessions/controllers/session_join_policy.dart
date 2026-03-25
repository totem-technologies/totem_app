part of 'session_controller.dart';

class SessionJoinPolicy {
  const SessionJoinPolicy();

  Future<void> apply({
    required Room room,
    required SessionRoomState state,
    required bool? cameraEnabledOverride,
    required bool? microphoneEnabledOverride,
    required SessionOptions? sessionOptions,
    required BoolGetter isCurrentUserKeeper,
    required AsyncCallback enableMicrophone,
    required AsyncCallback disableMicrophone,
  }) async {
    final cameraEnabled =
        cameraEnabledOverride ?? (sessionOptions?.cameraEnabled ?? false);
    room.localParticipant?.setCameraEnabled(cameraEnabled);

    // If joined in waiting room without keeper, user can start unmuted.
    // During active session, only current speaker can start unmuted.
    // Otherwise only keeper can start unmuted.
    final shouldEnableMicrophone = () {
      if (state.roomState.status == RoomStatus.waitingRoom &&
          !state.hasKeeper) {
        return microphoneEnabledOverride ?? sessionOptions?.microphoneEnabled;
      }
      if (state.roomState.status == RoomStatus.active &&
          state.speakingNow == room.localParticipant?.identity) {
        return microphoneEnabledOverride ?? sessionOptions?.microphoneEnabled;
      }
      return isCurrentUserKeeper() &&
          (microphoneEnabledOverride ??
              sessionOptions?.microphoneEnabled ??
              false);
    }();

    if (shouldEnableMicrophone ?? false) {
      await enableMicrophone();
    } else {
      await disableMicrophone();
    }
  }
}
