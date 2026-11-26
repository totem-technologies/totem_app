import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_events.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_reducer.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../../media/test_participants.dart';

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
    version: 0,
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

    turn: SessionTurnState(roomState: _roomState()),
  );
}

void main() {
  group('SessionStateReducer', () {
    const reducer = SessionStateReducer();

    group('ConnectionState', () {
      group('ReconnectingChanged event', () {
        SessionRoomState connected() => SessionRoomState(
          connection: const ConnectionState(
            phase: SessionPhase.connected,
            state: RoomConnectionState.connected,
          ),
          participants: const ParticipantsState(),
          turn: SessionTurnState(roomState: _roomState()),
        );

        test('marks a connected session as reconnecting and back', () {
          final reconnecting = reducer.reduceState(
            connected(),
            const ReconnectingChanged(isReconnecting: true),
          );
          check(reconnecting.connection.isReconnecting).isTrue();
          check(
            reconnecting.connection.state,
          ).equals(RoomConnectionState.connected);

          final recovered = reducer.reduceState(
            reconnecting,
            const ReconnectingChanged(isReconnecting: false),
          );
          check(recovered.connection.isReconnecting).isFalse();
        });

        test('a disconnect ends the reconnect attempt', () {
          final reconnecting = reducer.reduceState(
            connected(),
            const ReconnectingChanged(isReconnecting: true),
          );

          final next = reducer.reduceState(
            reconnecting,
            const ConnectionChanged(
              RoomConnectionState.disconnected,
              SessionPhase.disconnected,
            ),
          );

          check(next.connection.isReconnecting).isFalse();
        });
      });

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

        test('a transport failure without a LiveKit cause is an error too', () {
          // A failed rejoin on web: LiveKit's validate request couldn't fetch.
          final error = RoomTransportError(
            SessionTransportFailure(
              SessionTransportFailureKind.unexpected,
              'Failed to fetch',
              cause: ClientException('Failed to fetch'),
              stackTrace: StackTrace.empty,
            ),
          );

          final next = reducer.reduceState(
            _initialState(),
            SessionErrorChanged(error),
          );

          check(next.connection.error).equals(error);
          check(next.connection.state).equals(RoomConnectionState.error);
          check(next.phase).equals(SessionPhase.error);
        });

        test('an error ends a reconnect attempt', () {
          final reconnecting = SessionRoomState(
            connection: const ConnectionState(
              phase: SessionPhase.connected,
              state: RoomConnectionState.connected,
              isReconnecting: true,
            ),
            participants: const ParticipantsState(),
            turn: SessionTurnState(roomState: _roomState()),
          );

          final next = reducer.reduceState(
            reconnecting,
            SessionErrorChanged(RoomLiveKitError(MediaConnectException())),
          );

          check(next.connection.state).equals(RoomConnectionState.error);
          check(next.connection.isReconnecting).isFalse();
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
            RoomStateChanged(nextRoomState, observedAt: DateTime.utc(2026)),
          );

          check(next.roomState).equals(nextRoomState);
          check(next.phase).equals(SessionPhase.connecting);
        });

        test('sets phase ended when room ended', () {
          final current = _initialState();
          final nextRoomState = _roomState(status: RoomStatus.ended);

          final next = reducer.reduceState(
            current,
            RoomStateChanged(nextRoomState, observedAt: DateTime.utc(2026)),
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
            ).copyWith(version: 1, currentSpeaker: const Omittable(''));

            final next = reducer.reduceState(
              current,
              RoomStateChanged(active, observedAt: DateTime.utc(2026)),
            );

            check(next.speakingNow).equals('keeper');
            check(next.turnStartedAt).isNotNull();
          });

          test('stamps when speaker changes', () {
            final current = _initialState();

            final withSpeaker = _roomState(
              status: RoomStatus.active,
            ).copyWith(version: 1, currentSpeaker: const Omittable('user-1'));

            final next = reducer.reduceState(
              current,
              RoomStateChanged(withSpeaker, observedAt: DateTime.utc(2026)),
            );

            check(next.turnStartedAt).isNotNull();
          });

          test('clears the stamp when the room becomes inactive', () {
            final active = _roomState(
              status: RoomStatus.active,
            ).copyWith(version: 1, currentSpeaker: const Omittable('user-1'));
            final speaking = reducer.reduceState(
              _initialState(),
              RoomStateChanged(active, observedAt: DateTime.utc(2026)),
            );
            check(speaking.turnStartedAt).isNotNull();

            for (final status in [RoomStatus.waitingRoom, RoomStatus.ended]) {
              final inactive = reducer.reduceState(
                speaking,
                RoomStateChanged(
                  active.copyWith(version: 2, status: status),
                  observedAt: DateTime.utc(2026),
                ),
              );
              check(inactive.turnStartedAt).isNull();
            }
          });

          test('keeps existing stamp when same speaker continues', () {
            final current = _initialState();

            final active = _roomState(
              status: RoomStatus.active,
            ).copyWith(version: 1, currentSpeaker: const Omittable('user-1'));

            final first = reducer.reduceState(
              current,
              RoomStateChanged(active, observedAt: DateTime.utc(2026)),
            );
            final stamp = first.turnStartedAt!;

            // Metadata bump — same speaker.
            final bumped = active.copyWith(version: 2);
            final second = reducer.reduceState(
              first,
              RoomStateChanged(bumped, observedAt: DateTime.utc(2026)),
            );

            check(second.turnStartedAt).identicalTo(stamp);
          });

          test('carries forward through non-room-state events', () {
            final current = _initialState();

            final active = _roomState(
              status: RoomStatus.active,
            ).copyWith(version: 1, currentSpeaker: const Omittable('user-1'));

            final afterRoom = reducer.reduceState(
              current,
              RoomStateChanged(active, observedAt: DateTime.utc(2026)),
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
            final original = testParticipant('original');
            final replacement = testParticipant('replacement');
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

    test('stale and duplicate versions cannot replace accepted room state', () {
      final accepted = reducer.reduceState(
        _initialState(),
        RoomStateChanged(
          _roomState(status: RoomStatus.active).copyWith(version: 5),
          observedAt: DateTime.utc(2026),
        ),
      );
      for (final version in [4, 5]) {
        final rejected = reducer.reduceState(
          accepted,
          RoomStateChanged(
            _roomState().copyWith(version: version),
            observedAt: DateTime.utc(2027),
          ),
        );
        check(rejected).identicalTo(accepted);
      }
      final ended = reducer.reduceState(
        accepted,
        RoomStateChanged(
          accepted.roomState.copyWith(status: RoomStatus.ended),
          observedAt: DateTime.utc(2027),
        ),
      );
      check(ended.roomState.status).equals(RoomStatus.ended);
      check(ended.roomState.version).equals(5);
    });

    test('same state and timestamp produce deterministic turn timing', () {
      final current = _initialState();
      final event = RoomStateChanged(
        _roomState(status: RoomStatus.active).copyWith(version: 1),
        observedAt: DateTime.utc(2026),
      );
      final first = reducer.reduceState(current, event);
      final second = reducer.reduceState(current, event);
      check(first).equals(second);
      check(first.turnStartedAt).equals(event.observedAt);
      check(current.turnStartedAt).isNull();
    });
  });
}
