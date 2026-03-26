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
      error: RoomDisconnectionError(DisconnectReason.disconnected),
    ),
    participants: const ParticipantsState(removed: true),
    chat: const ChatState(),
    turn: SessionTurnState(roomState: _roomState()),
  );
}

void main() {
  group('SessionStateReducer', () {
    const reducer = SessionStateReducer();

    group('ConnectionState', () {
      group('ConnectionChanged event', () {
        test('resets removed and clears error when connected', () {
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
        });

        test('keeps existing error when disconnected', () {
          final current = SessionRoomState(
            connection: const ConnectionState(
              phase: SessionPhase.connecting,
              state: RoomConnectionState.connecting,
              error: RoomDisconnectionError(DisconnectReason.disconnected),
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

        test('tracks state changes correctly', () {
          var state = _initialState();
          expect(state.connection.state, RoomConnectionState.connecting);

          state = reducer.reduceState(
            state,
            const ConnectionChanged(
              RoomConnectionState.connected,
              SessionPhase.connected,
            ),
          );
          expect(state.connection.state, RoomConnectionState.connected);

          state = reducer.reduceState(
            state,
            const ConnectionChanged(
              RoomConnectionState.disconnected,
              SessionPhase.disconnected,
            ),
          );
          expect(state.connection.state, RoomConnectionState.disconnected);
        });

        test('transitions phases correctly', () {
          var state = SessionRoomState(
            connection: const ConnectionState(
              phase: SessionPhase.idle,
              state: RoomConnectionState.disconnected,
            ),
            participants: const ParticipantsState(),
            chat: const ChatState(),
            turn: SessionTurnState(roomState: _roomState()),
          );
          expect(state.connection.phase, SessionPhase.idle);

          state = reducer.reduceState(
            state,
            const ConnectionChanged(
              RoomConnectionState.connecting,
              SessionPhase.connecting,
            ),
          );
          expect(state.connection.phase, SessionPhase.connecting);

          state = reducer.reduceState(
            state,
            const ConnectionChanged(
              RoomConnectionState.connected,
              SessionPhase.connected,
            ),
          );
          expect(state.connection.phase, SessionPhase.connected);

          state = reducer.reduceState(
            state,
            const ConnectionChanged(
              RoomConnectionState.disconnected,
              SessionPhase.disconnected,
            ),
          );
          expect(state.connection.phase, SessionPhase.disconnected);
        });
      });

      group('SessionErrorChanged event', () {
        test('sets error state for livekit errors', () {
          final current = _initialState();
          final error = RoomLiveKitError(
            ConnectException(
              'failed',
              reason: ConnectionErrorReason.NotAllowed,
            ),
          );

          final next = reducer.reduceState(current, SessionErrorChanged(error));

          expect(next.connection.error, error);
          expect(next.connection.state, RoomConnectionState.error);
          expect(next.phase, SessionPhase.error);
        });

        test('preserves state for non-livekit errors', () {
          final current = _initialState();
          const error = RoomDisconnectionError(DisconnectReason.disconnected);

          final next = reducer.reduceState(
            current,
            const SessionErrorChanged(error),
          );

          expect(next.connection.error, error);
          expect(next.connection.state, current.connection.state);
          expect(next.phase, current.phase);
        });

        test('handles error state properly', () {
          var state = _initialState();

          final error = RoomLiveKitError(
            ConnectException(
              'Connection failed',
              reason: ConnectionErrorReason.NotAllowed,
            ),
          );

          state = reducer.reduceState(
            state,
            SessionErrorChanged(error),
          );

          expect(state.connection.error, isNotNull);
          expect(state.connection.state, RoomConnectionState.error);
        });
      });

      group('Unrelated connection events', () {
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
      });
    });

    group('RoomState', () {
      group('RoomStateChanged event', () {
        test('updates room state', () {
          final current = _initialState();
          final nextRoomState = _roomState(status: RoomStatus.active);

          final next = reducer.reduceState(
            current,
            RoomStateChanged(nextRoomState),
          );

          expect(next.roomState.status, RoomStatus.active);
          expect(next.phase, SessionPhase.connecting);
        });

        test('sets phase ended when room ended', () {
          final current = _initialState();
          final nextRoomState = _roomState(status: RoomStatus.ended);

          final next = reducer.reduceState(
            current,
            RoomStateChanged(nextRoomState),
          );

          expect(next.roomState.status, RoomStatus.ended);
          expect(next.phase, SessionPhase.ended);
        });

        test('applies room state updates correctly', () {
          var state = _initialState();

          const newRoomState = RoomState(
            keeper: 'keeper-1',
            nextSpeaker: 'user-2',
            currentSpeaker: 'user-1',
            status: RoomStatus.active,
            turnState: TurnState.speaking,
            sessionSlug: 'test-session',
            statusDetail: RoomStateStatusDetailActive(
              ActiveDetail(),
            ),
            talkingOrder: ['user-1', 'user-2'],
            version: 2,
            roundNumber: 1,
          );

          state = reducer.reduceState(
            state,
            const RoomStateChanged(newRoomState),
          );

          expect(state.roomState.status, RoomStatus.active);
          expect(state.roomState.version, 2);
          expect(state.roomState.talkingOrder, contains('user-1'));
        });
      });
    });

    group('ParticipantsState', () {
      group('ParticipantRemoved event', () {
        test('marks removed flag', () {
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

        test('dispatches event correctly', () {
          final state = _initialState();

          final newState = reducer.reduceState(
            state,
            const ParticipantRemoved(),
          );

          expect(newState.removed, isTrue);
        });

        test('tracks removal flag', () {
          var state = SessionRoomState(
            connection: const ConnectionState(
              phase: SessionPhase.idle,
              state: RoomConnectionState.disconnected,
            ),
            participants: const ParticipantsState(),
            chat: const ChatState(),
            turn: SessionTurnState(roomState: _roomState()),
          );
          expect(state.removed, isFalse);

          state = reducer.reduceState(
            state,
            const ParticipantRemoved(),
          );

          expect(state.removed, isTrue);
        });
      });

      group('ParticipantsChanged event', () {
        test('replaces participants list', () {
          final current = _initialState();
          final participants = <Participant>[];

          final next = reducer.reduceState(
            current,
            ParticipantsChanged(participants),
          );

          expect(next.participantsList, isEmpty);
        });
      });

      group('KeeperDisconnectedChanged event', () {
        test('updates keeper disconnected flag', () {
          final current = _initialState();

          final next = reducer.reduceState(
            current,
            const KeeperDisconnectedChanged(true),
          );

          expect(next.hasKeeperDisconnected, isTrue);
        });

        test('dispatches event correctly', () {
          final state = _initialState();

          var newState = reducer.reduceState(
            state,
            const KeeperDisconnectedChanged(true),
          );

          expect(newState.hasKeeperDisconnected, isTrue);

          newState = reducer.reduceState(
            newState,
            const KeeperDisconnectedChanged(false),
          );

          expect(newState.hasKeeperDisconnected, isFalse);
        });

        test('toggles keeper disconnection status', () {
          var state = _initialState();
          expect(state.hasKeeperDisconnected, isFalse);

          state = reducer.reduceState(
            state,
            const KeeperDisconnectedChanged(true),
          );
          expect(state.hasKeeperDisconnected, isTrue);

          state = reducer.reduceState(
            state,
            const KeeperDisconnectedChanged(false),
          );
          expect(state.hasKeeperDisconnected, isFalse);
        });
      });
    });

    group('ChatState', () {
      group('SessionChatMessageAdded event', () {
        test('appends message', () {
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

        test('dispatches event correctly', () {
          final state = _initialState();
          const message = SessionChatMessage(
            message: 'Test message',
            timestamp: 1000,
            id: 'msg-1',
            sender: true,
          );

          final newState = reducer.reduceState(
            state,
            const SessionChatMessageAdded(message),
          );

          expect(newState.messages, hasLength(1));
          expect(newState.messages.first.message, 'Test message');
          expect(newState.messages.first.id, 'msg-1');
        });

        test('maintains message order', () {
          var state = _initialState();

          for (int i = 0; i < 5; i++) {
            state = reducer.reduceState(
              state,
              SessionChatMessageAdded(
                SessionChatMessage(
                  message: 'Message $i',
                  timestamp: i,
                  id: 'msg-$i',
                  sender: i.isEven,
                ),
              ),
            );
          }

          expect(state.messages, hasLength(5));
          for (int i = 0; i < 5; i++) {
            expect(state.messages[i].id, 'msg-$i');
          }
        });
      });
    });

    group('TurnState', () {
      group('SpeakerphoneChanged event', () {
        test('updates speakerphone flag', () {
          final current = _initialState();

          final next = reducer.reduceState(
            current,
            const SpeakerphoneChanged(true),
          );

          expect(next.isSpeakerphoneEnabled, isTrue);
        });

        test('dispatches event correctly', () {
          final state = _initialState();

          var newState = reducer.reduceState(
            state,
            const SpeakerphoneChanged(true),
          );

          expect(newState.isSpeakerphoneEnabled, isTrue);

          newState = reducer.reduceState(
            newState,
            const SpeakerphoneChanged(false),
          );

          expect(newState.isSpeakerphoneEnabled, isFalse);
        });

        test('toggles preference', () {
          var state = _initialState();
          final initialState = state.isSpeakerphoneEnabled;

          state = reducer.reduceState(
            state,
            SpeakerphoneChanged(!initialState),
          );

          expect(state.isSpeakerphoneEnabled, !initialState);
        });
      });
    });

    group('State immutability', () {
      test('original state not modified when adding message', () {
        final originalState = _initialState();
        final originalMessageCount = originalState.messages.length;

        final _ = reducer.reduceState(
          originalState,
          const SessionChatMessageAdded(
            SessionChatMessage(
              message: 'New message',
              timestamp: 5000,
              id: 'msg-new',
              sender: true,
            ),
          ),
        );

        expect(originalState.messages.length, originalMessageCount);
      });
    });
  });
}
