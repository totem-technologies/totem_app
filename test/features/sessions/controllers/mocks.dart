import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:livekit_client/src/core/engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';

class MockSessionController extends Mock implements SessionController {}

class MockSessionDeviceController extends Mock
    implements SessionDeviceController {}

class MockLocalParticipant extends Mock implements LocalParticipant {
  MockLocalParticipant([this.id = 'local-participant']);
  final String id;

  @override
  String get identity => id;

  @override
  String get sid => id;

  @override
  List<LocalTrackPublication<LocalAudioTrack>> get audioTrackPublications => [];

  @override
  List<LocalTrackPublication<LocalVideoTrack>> get videoTrackPublications => [];

  @override
  List<LocalTrackPublication<LocalTrack>> getTrackPublications() => [];
}

class FakeRoom extends Fake implements Room {
  FakeRoom(this.participant);

  final MockLocalParticipant participant;

  @override
  LocalParticipant get localParticipant => participant;

  bool _speakerOn = false;

  // We have to use extension methods or noSuchMethod to bypass properties that aren't overridable
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #engine) return FakeEngine();
    if (invocation.memberName == #roomOptions) return const RoomOptions();
    if (invocation.memberName == #speakerOn) return _speakerOn;
    if (invocation.memberName == #setSpeakerOn) {
      _speakerOn = invocation.positionalArguments[0] as bool;
      return Future<void>.value();
    }
    if (invocation.memberName == #selectedVideoInputDeviceId) return null;
    return super.noSuchMethod(invocation);
  }
}

class FakeEngine extends Fake implements Engine {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #roomOptions) return const RoomOptions();
    return super.noSuchMethod(invocation);
  }
}

class FakeCameraCaptureOptions extends Fake implements CameraCaptureOptions {}

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

class FakeSessionDeviceController implements SessionDeviceController {
  bool disableMicrophoneCalled = false;
  bool enableMicrophoneCalled = false;

  @override
  Future<void> disableMicrophone() async {
    disableMicrophoneCalled = true;
  }

  @override
  Future<void> enableMicrophone() async {
    enableMicrophoneCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
