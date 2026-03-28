import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';
import '../../livekit_mocks.dart';
import '../features/session_device_controller_mock.dart';

class MockSessionController extends Mock implements SessionController {}

RoomState _createRoomState({RoomStatus status = RoomStatus.waitingRoom}) {
  return RoomState(
    keeper: 'keeper-1',
    nextSpeaker: 'user-2',
    currentSpeaker: 'user-1',
    status: status,
    turnState: TurnState.idle,
    sessionSlug: 'test-session',
    statusDetail: const RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
    talkingOrder: const [],
    version: 1,
    roundNumber: 1,
  );
}

SessionRoomState _createSessionState({
  RoomStatus roomStatus = RoomStatus.waitingRoom,
}) {
  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(
      participants: [
        MockLocalParticipant('user-1'),
        MockLocalParticipant('user-2'),
        MockLocalParticipant('keeper-1'),
      ],
    ),
    chat: const ChatState(),
    turn: SessionTurnState(roomState: _createRoomState(status: roomStatus)),
  );
}

class FakeSessionController implements SessionController {
  SessionRoomState mockState = _createSessionState();
  SessionDeviceController mockDevices = FakeSessionDeviceController();
  bool disconnectFromRoomCalled = false;
  bool? lastKeeperDisconnectedValue;
  List<SessionChatMessage> addedChatMessages = [];
  bool isCurrentUserKeeperValue = false;
  Room? mockRoom;

  @override
  SessionRoomState get state => mockState;

  @override
  SessionDeviceController get devices => mockDevices;

  @override
  Room? get room => mockRoom;

  @override
  Future<void> disconnectFromRoom() async {
    disconnectFromRoomCalled = true;
  }

  @override
  void setKeeperDisconnected(bool hasKeeperDisconnected) {
    lastKeeperDisconnectedValue = hasKeeperDisconnected;
  }

  @override
  void addSessionChatMessage(SessionChatMessage message) {
    addedChatMessages.add(message);
  }

  @override
  bool isCurrentUserKeeper() {
    return isCurrentUserKeeperValue;
  }

  @override
  void markParticipantRemoved() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
