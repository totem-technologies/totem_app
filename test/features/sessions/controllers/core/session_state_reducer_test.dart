import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state_events.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state_reducer.dart';
import 'package:totem_app/features/sessions/controllers/features/session_messaging_controller.dart';

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

    test('RoomStateChanged updates room state', () {
      final current = _initialState();
      final nextRoomState = _roomState(status: RoomStatus.active);

      final next = reducer.reduceState(
        current,
        RoomStateChanged(nextRoomState),
      );

      expect(next.roomState.status, RoomStatus.active);
      expect(next.phase, SessionPhase.connecting);
    });

    test('RoomStateChanged sets phase ended when room ended', () {
      final current = _initialState();
      final nextRoomState = _roomState(status: RoomStatus.ended);

      final next = reducer.reduceState(
        current,
        RoomStateChanged(nextRoomState),
      );

      expect(next.roomState.status, RoomStatus.ended);
      expect(next.phase, SessionPhase.ended);
    });

    test('ParticipantsChanged replaces participants list', () {
      final current = _initialState();
      final participants = <Participant>[];

      final next = reducer.reduceState(
        current,
        ParticipantsChanged(participants),
      );

      expect(next.participantsList, isEmpty);
    });

    test('KeeperDisconnectedChanged updates keeper disconnected flag', () {
      final current = _initialState();

      final next = reducer.reduceState(
        current,
        const KeeperDisconnectedChanged(true),
      );

      expect(next.hasKeeperDisconnected, isTrue);
    });

    test('SpeakerphoneChanged updates speakerphone flag', () {
      final current = _initialState();

      final next = reducer.reduceState(
        current,
        const SpeakerphoneChanged(true),
      );

      expect(next.isSpeakerphoneEnabled, isTrue);
    });

    test('SessionErrorChanged sets error state for livekit errors', () {
      final current = _initialState();
      final error = RoomLiveKitError(
        ConnectException('failed', reason: ConnectionErrorReason.NotAllowed),
      );

      final next = reducer.reduceState(current, SessionErrorChanged(error));

      expect(next.connection.error, error);
      expect(next.connection.state, RoomConnectionState.error);
      expect(next.phase, SessionPhase.error);
    });

    test('SessionErrorChanged preserves state for non-livekit errors', () {
      final current = _initialState();
      const error = RoomTimeoutError(SessionPhase.connecting);

      final next = reducer.reduceState(
        current,
        const SessionErrorChanged(error),
      );

      expect(next.connection.error, error);
      expect(next.connection.state, current.connection.state);
      expect(next.phase, current.phase);
    });

    test('DisconnectReasonChanged keeps state unchanged', () {
      final current = _initialState();

      final next = reducer.reduceState(
        current,
        const DisconnectReasonChanged(DisconnectReason.unknown),
      );

      expect(next, current);
    });

    test('LiveKitErrorChanged keeps state unchanged', () {
      final current = _initialState();

      final next = reducer.reduceState(
        current,
        LiveKitErrorChanged(
          UnexpectedStateException('error'),
        ),
      );

      expect(next, current);
    });

    test('ConnectionChanged when disconnected keeps existing error', () {
      final current = SessionRoomState(
        connection: const ConnectionState(
          phase: SessionPhase.connecting,
          state: RoomConnectionState.connecting,
          error: RoomTimeoutError(SessionPhase.connecting),
        ),
        participants: const ParticipantsState(removed: false),
        chat: const ChatState(),
        turn: SessionTurnState(roomState: _roomState()),
      );

      final next = reducer.reduceState(
        current,
        const ConnectionChanged(
          RoomConnectionState.disconnected,
          SessionPhase.disconnected,
        ),
      );

      expect(next.connection.error, isNotNull);
      expect(next.connection.state, RoomConnectionState.disconnected);
      expect(next.phase, SessionPhase.disconnected);
    });
  });
}
