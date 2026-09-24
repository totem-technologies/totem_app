import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_events.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_reducer.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';

class _Participant extends Mock implements Participant {}

RoomState _roomState({RoomStatus status = RoomStatus.waitingRoom}) {
  return RoomState(
    keeper: 'keeper',
    nextSpeaker: const Omittable(''),
    currentSpeaker: const Omittable(''),
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

          check(next.connection.state).equals(RoomConnectionState.connected);
          check(next.connection.phase).equals(SessionPhase.connected);
          check(next.connection.error).isNull();
          check(next.removed).equals(false);
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

          check(next.connection.error).isNotNull();
          check(next.connection.state).equals(RoomConnectionState.disconnected);
          check(next.phase).equals(SessionPhase.disconnected);
        });
      });

      test(
        'clears existing error when transitioning to connecting (retry)',
        () {
          final current = _initialState();

          final next = reducer.reduceState(
            current,
            const ConnectionChanged(
              RoomConnectionState.connecting,
              SessionPhase.connecting,
            ),
          );

          check(next.connection.state).equals(RoomConnectionState.connecting);
          check(next.connection.phase).equals(SessionPhase.connecting);
          check(next.connection.error).isNull();
        },
      );

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

          check(next.connection.error).equals(error);
          check(next.connection.state).equals(RoomConnectionState.error);
          check(next.phase).equals(SessionPhase.error);
        });

        test('preserves state for non-livekit errors', () {
          final current = _initialState();
          const error = RoomDisconnectionError(DisconnectReason.disconnected);

          final next = reducer.reduceState(
            current,
            const SessionErrorChanged(error),
          );

          check(next.connection.error).equals(error);
          check(next.connection.state).equals(current.connection.state);
          check(next.phase).equals(current.phase);
        });
      });
    });

    group('RoomState', () {
      group('RoomStateChanged event', () {
        test('updates room state', () {
          final current = _initialState();
          final nextRoomState = _roomState(
            status: RoomStatus.active,
          ).copyWith(version: 2, talkingOrder: ['user-1', 'user-2']);

          final next = reducer.reduceState(
            current,
            RoomStateChanged(nextRoomState),
          );

          check(next.roomState).equals(nextRoomState);
          check(next.phase).equals(SessionPhase.connecting);
        });

        test('sets phase ended when room ended', () {
          final current = _initialState();
          final nextRoomState = _roomState(status: RoomStatus.ended);

          final next = reducer.reduceState(
            current,
            RoomStateChanged(nextRoomState),
          );

          check(next.roomState.status).equals(RoomStatus.ended);
          check(next.phase).equals(SessionPhase.ended);
        });

        group('turnStartedAt', () {
          test('stamps on keeper opening turn (currentSpeaker empty)', () {
            final current = _initialState();
            check(current.turnStartedAt).isNull();

            // Room goes active — speakerOf falls back to keeper.
            final active = _roomState(
              status: RoomStatus.active,
            ).copyWith(currentSpeaker: const Omittable(''));

            final next = reducer.reduceState(current, RoomStateChanged(active));

            check(next.turnStartedAt).isNotNull();
          });

          test('stamps when speaker changes', () {
            final current = _initialState();

            final withSpeaker = _roomState(
              status: RoomStatus.active,
            ).copyWith(currentSpeaker: const Omittable('user-1'));

            final next = reducer.reduceState(
              current,
              RoomStateChanged(withSpeaker),
            );

            check(next.turnStartedAt).isNotNull();
          });

          test('keeps existing stamp when same speaker continues', () {
            final current = _initialState();

            final active = _roomState(
              status: RoomStatus.active,
            ).copyWith(currentSpeaker: const Omittable('user-1'));

            final first = reducer.reduceState(
              current,
              RoomStateChanged(active),
            );
            final stamp = first.turnStartedAt!;

            // Metadata bump — same speaker.
            final bumped = active.copyWith(version: 2);
            final second = reducer.reduceState(first, RoomStateChanged(bumped));

            check(second.turnStartedAt).identicalTo(stamp);
          });

          test('carries forward through non-room-state events', () {
            final current = _initialState();

            final active = _roomState(
              status: RoomStatus.active,
            ).copyWith(currentSpeaker: const Omittable('user-1'));

            final afterRoom = reducer.reduceState(
              current,
              RoomStateChanged(active),
            );
            final stamp = afterRoom.turnStartedAt!;

            final afterParticipants = reducer.reduceState(
              afterRoom,
              const ParticipantsChanged([]),
            );
            check(afterParticipants.turnStartedAt).identicalTo(stamp);

            final afterError = reducer.reduceState(
              afterRoom,
              const SessionErrorChanged(
                RoomDisconnectionError(DisconnectReason.disconnected),
              ),
            );
            check(afterError.turnStartedAt).identicalTo(stamp);
          });
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

          final next = reducer.reduceState(
            current,
            const ParticipantRemoved(RemoveReason.remove),
          );

          check(next.removed).equals(true);
          check(next.participants.removeReason).equals(RemoveReason.remove);
        });
      });

      group('ParticipantsChanged event', () {
        test(
          'replaces and clears participants without changing the prior state',
          () {
            final original = _Participant();
            final replacement = _Participant();
            final current = reducer.reduceState(
              _initialState(),
              ParticipantsChanged([original]),
            );

            final next = reducer.reduceState(
              current,
              ParticipantsChanged([replacement]),
            );
            check(next.participantsList).deepEquals([replacement]);
            check(current.participantsList).deepEquals([original]);

            final cleared = reducer.reduceState(
              next,
              const ParticipantsChanged([]),
            );
            check(cleared.participantsList).isEmpty();
            check(next.participantsList).deepEquals([replacement]);
          },
        );
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

          check(next.messages).length.equals(1);
          check(next.messages.first.id).equals('m1');
          check(next.messages.first.message).equals('hello');
        });

        test('ignores a message with an existing ID', () {
          const message = SessionChatMessage(
            message: 'hello',
            timestamp: 123,
            id: 'm1',
            sender: true,
          );
          final current = reducer.reduceState(
            _initialState(),
            const SessionChatMessageAdded(message),
          );

          final next = reducer.reduceState(
            current,
            const SessionChatMessageAdded(message),
          );

          check(next.messages).length.equals(1);
          check(next.messages.single.id).equals('m1');
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

          check(state.messages).length.equals(5);
          for (int i = 0; i < 5; i++) {
            check(state.messages[i].id).equals('msg-$i');
          }
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

        check(originalState.messages).length.equals(originalMessageCount);
      });
    });
  });
}
