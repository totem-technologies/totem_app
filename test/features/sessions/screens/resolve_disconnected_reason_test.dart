import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/screens/session_disconnected.dart';

SessionRoomState _createState({
  RoomStatus status = RoomStatus.ended,
  EndReason endReason = EndReason.keeperEnded,
  bool removed = false,
}) {
  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.ended,
      state: RoomConnectionState.disconnected,
    ),
    participants: ParticipantsState(
      participants: const [],
      removed: removed,
    ),
    chat: const ChatState(),
    turn: SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: '',
        currentSpeaker: '',
        status: status,
        turnState: TurnState.idle,
        sessionSlug: 'test-session',
        statusDetail: status == RoomStatus.ended
            ? RoomStateStatusDetailEnded(
                EndedDetail(reason: endReason),
              )
            : const RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

void main() {
  group('resolveDisconnectedReason', () {
    test('returns movedToAnotherDevice when duplicateIdentity', () {
      final result = resolveDisconnectedReason(
        disconnectReason: DisconnectReason.duplicateIdentity,
        sessionState: _createState(),
      );

      expect(result, SessionDisconnectedReason.movedToAnotherDevice);
    });

    test('duplicateIdentity takes priority over removed', () {
      final result = resolveDisconnectedReason(
        disconnectReason: DisconnectReason.duplicateIdentity,
        sessionState: _createState(removed: true),
      );

      expect(result, SessionDisconnectedReason.movedToAnotherDevice);
    });

    test('returns removed when participant was removed', () {
      final result = resolveDisconnectedReason(
        sessionState: _createState(removed: true),
      );

      expect(result, SessionDisconnectedReason.removed);
    });

    test('removed takes priority over endReason', () {
      final result = resolveDisconnectedReason(
        sessionState: _createState(
          removed: true,
          endReason: EndReason.keeperAbsent,
        ),
      );

      expect(result, SessionDisconnectedReason.removed);
    });

    test('returns keeperAbsent when EndReason.keeperAbsent', () {
      final result = resolveDisconnectedReason(
        sessionState: _createState(endReason: EndReason.keeperAbsent),
      );

      expect(result, SessionDisconnectedReason.keeperAbsent);
    });

    test('returns roomEmpty when EndReason.roomEmpty', () {
      final result = resolveDisconnectedReason(
        sessionState: _createState(endReason: EndReason.roomEmpty),
      );

      expect(result, SessionDisconnectedReason.roomEmpty);
    });

    test('returns keeperEnded when EndReason.keeperEnded', () {
      final result = resolveDisconnectedReason(
        sessionState: _createState(endReason: EndReason.keeperEnded),
      );

      expect(result, SessionDisconnectedReason.keeperEnded);
    });

    test('returns keeperEnded for unrecognized EndReason values', () {
      final result = resolveDisconnectedReason(
        sessionState: _createState(
          endReason: EndReason.fromJson('some_unknown'),
        ),
      );

      expect(result, SessionDisconnectedReason.keeperEnded);
    });

    test('returns keeperEnded when sessionState is null', () {
      final result = resolveDisconnectedReason();

      expect(result, SessionDisconnectedReason.keeperEnded);
    });

    test('returns keeperEnded when room status is not ended', () {
      final result = resolveDisconnectedReason(
        sessionState: _createState(status: RoomStatus.active),
      );

      expect(result, SessionDisconnectedReason.keeperEnded);
    });
  });
}
