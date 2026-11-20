import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_events.dart';

class SessionStateReducer {
  const SessionStateReducer();

  SessionRoomState reduceState(SessionRoomState current, SessionEvent event) {
    switch (event) {
      case ConnectionChanged():
        return SessionRoomState(
          connection: current.connection.copyWith(
            state: event.connectionState,
            phase: event.phase,
            // Clear any prior error when transitioning to connecting or
            // connected (e.g. a retry), so the UI reflects the current
            // attempt instead of showing a stale error.
            clearError:
                event.connectionState == RoomConnectionState.connected ||
                event.connectionState == RoomConnectionState.connecting,
            wasJoining: event.wasJoining,
            // Any connection transition ends a reconnect attempt: it either
            // recovered (connected) or gave up (disconnected/error).
            isReconnecting: false,
          ),
          participants: event.connectionState == RoomConnectionState.connected
              ? current.participants.copyWith(removed: false)
              : current.participants,
          turn: current.turn,
          turnStartedAt: current.turnStartedAt,
        );
      case ReconnectingChanged():
        return SessionRoomState(
          connection: current.connection.copyWith(
            isReconnecting: event.isReconnecting,
          ),
          participants: current.participants,
          turn: current.turn,
          turnStartedAt: current.turnStartedAt,
        );
      case RoomStateChanged():
        final isEnding =
            current.roomState.status != RoomStatus.ended &&
            event.roomState.status == RoomStatus.ended;
        if (event.roomState.version < current.roomState.version ||
            (event.roomState.version == current.roomState.version &&
                !isEnding)) {
          return current;
        }
        final isEnded = event.roomState.status == RoomStatus.ended;
        final newSpeaker = SessionRoomState.speakerOf(event.roomState);
        final turnStartedAt =
            event.roomState.status != RoomStatus.active || newSpeaker.isEmpty
            ? null
            : current.speakingNow != newSpeaker || current.turnStartedAt == null
            ? event.observedAt
            : current.turnStartedAt;
        return SessionRoomState(
          connection: current.connection.copyWith(
            phase: isEnded ? SessionPhase.ended : null,
          ),
          participants: current.participants,
          turn: current.turn.copyWith(roomState: event.roomState),
          turnStartedAt: turnStartedAt,
        );
      case ParticipantsChanged():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(
            participants: event.participants,
          ),
          turn: current.turn,
          turnStartedAt: current.turnStartedAt,
        );
      case ParticipantRemoved():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(
            removed: true,
            removeReason: event.reason,
          ),
          turn: current.turn,
          turnStartedAt: current.turnStartedAt,
        );
      case SessionErrorChanged():
        // Connection failures show the error screen, whether or not LiveKit
        // raised them, and end any reconnect attempt.
        final isConnectionFailure =
            event.error is RoomLiveKitError ||
            event.error is RoomTransportError;
        return SessionRoomState(
          connection: current.connection.copyWith(
            error: event.error,
            state: isConnectionFailure
                ? RoomConnectionState.error
                : current.connection.state,
            phase: isConnectionFailure ? SessionPhase.error : null,
            isReconnecting:
                current.connection.isReconnecting && !isConnectionFailure,
          ),
          participants: current.participants,
          turn: current.turn,
          turnStartedAt: current.turnStartedAt,
        );
    }
  }
}
