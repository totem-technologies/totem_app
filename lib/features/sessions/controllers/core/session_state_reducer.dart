import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state_events.dart';

class SessionStateReducer {
  const SessionStateReducer();

  SessionRoomState reduceState(SessionRoomState current, SessionEvent event) {
    switch (event) {
      case ConnectionChanged():
        return SessionRoomState(
          connection: current.connection.copyWith(
            state: event.connectionState,
            phase: event.phase,
            clearError: event.connectionState == RoomConnectionState.connected,
          ),
          participants: event.connectionState == RoomConnectionState.connected
              ? current.participants.copyWith(removed: false)
              : current.participants,
          chat: current.chat,
          turn: current.turn,
        );
      case RoomStateChanged():
        final isEnded = event.roomState.status == RoomStatus.ended;
        return SessionRoomState(
          connection: current.connection.copyWith(
            phase: isEnded ? SessionPhase.ended : null,
          ),
          participants: current.participants,
          chat: current.chat,
          turn: current.turn.copyWith(roomState: event.roomState),
        );
      case ParticipantsChanged():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(
            participants: event.participants,
          ),
          chat: current.chat,
          turn: current.turn,
        );
      case KeeperDisconnectedChanged():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(
            hasKeeperDisconnected: event.hasKeeperDisconnected,
          ),
          chat: current.chat,
          turn: current.turn,
        );
      case ParticipantRemoved():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(removed: true),
          chat: current.chat,
          turn: current.turn,
        );
      case SessionErrorChanged():
        return SessionRoomState(
          connection: current.connection.copyWith(
            error: event.error,
            state: event.error is RoomLiveKitError
                ? RoomConnectionState.error
                : current.connection.state,
            phase: event.error is RoomLiveKitError ? SessionPhase.error : null,
          ),
          participants: current.participants,
          chat: current.chat,
          turn: current.turn,
        );
      case SessionChatMessageAdded():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants,
          chat: current.chat.copyWith(
            messages: [...current.chat.messages, event.message],
          ),
          turn: current.turn,
        );
    }
  }
}
