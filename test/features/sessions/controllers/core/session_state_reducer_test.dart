import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_chat_message.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state_events.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state_reducer.dart';

RoomState _roomState({RoomStatus status = RoomStatus.waitingRoom}) {
  return RoomState(
    keeper: 'keeper',
    nextSpeaker: '',
    currentSpeaker: '',
    status: status,
    turnState: TurnState.idle,
    sessionSlug: 'session-1',
    statusDetail: const RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
    talkingOrder: const [],
    version: 1,
    roundNumber: 1,
  );
}

SessionRoomState _initialState() {
  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connecting,
      state: RoomConnectionState.connecting,
      error: RoomTimeoutError(SessionPhase.connecting),
    ),
    participants: const ParticipantsState(removed: true),
    chat: const ChatState(),
    turn: SessionTurnState(roomState: _roomState()),
  );
}

void main() {
  group('SessionStateReducer', () {
    const reducer = SessionStateReducer();

    test(
      'ConnectionChanged resets removed and clears error when connected',
      () {
        final current = _initialState();

        final next = reducer.reduceState(
          current,
          const ConnectionChanged(
            RoomConnectionState.connected,
            SessionPhase.connected,
          ),
        );

        expect(next.connection.state, RoomConnectionState.connected);
        expect(next.connection.phase, SessionPhase.connected);
        expect(next.connection.error, isNull);
        expect(next.removed, isFalse);
      },
    );

    test('ParticipantRemoved marks removed flag', () {
      final current = SessionRoomState(
        connection: const ConnectionState(
          phase: SessionPhase.connecting,
          state: RoomConnectionState.connecting,
        ),
        participants: const ParticipantsState(removed: false),
        chat: const ChatState(),
        turn: SessionTurnState(roomState: _roomState()),
      );

      final next = reducer.reduceState(current, const ParticipantRemoved());

      expect(next.removed, isTrue);
    });

    test('SessionChatMessageAdded appends message', () {
      final current = _initialState();
      const message = SessionChatMessage(
        message: 'hello',
        timestamp: 123,
        id: 'm1',
        sender: true,
      );

      final next = reducer.reduceState(
        current,
        const SessionChatMessageAdded(message),
      );

      expect(next.messages.length, 1);
      expect(next.messages.first.id, 'm1');
      expect(next.messages.first.message, 'hello');
    });
  });
}
