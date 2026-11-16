import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_runtime.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/services/session_chat_service.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';
import 'package:totem_core/features/sessions/services/session_moderation_service.dart';
import 'package:totem_core/features/sessions/services/session_reaction_buffer.dart';
import 'package:totem_core/features/sessions/services/session_reactions_service.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../../media/fake_local_media.dart';
import '../../media/fake_room_media.dart';
import '../../media/test_participants.dart';
import '../../media/test_room_transport.dart';
import '../features/session_device_controller_mock.dart';

const testSessionOptions = SessionOptions(
  sessionSlug: 'test-session',
  token: 'test-token',
  cameraEnabled: false,
  microphoneEnabled: false,
  speakerEnabled: true,
  cameraOptions: SessionController.defaultCameraCaptureOptions,
);

class MockSessionController extends Mock implements SessionController {
  @override
  final SessionAdmissionService admission = FakeAdmissionService();
  FakeLocalMedia mockLocalMedia = FakeLocalMedia();
  FakeRoomMedia mockRoomMedia = FakeRoomMedia();

  @override
  bool shouldEnableMicrophone() => options.microphoneEnabled;

  @override
  LocalMedia get localMedia => mockLocalMedia;

  @override
  RoomMedia get roomMedia => mockRoomMedia;
}

RoomState _createRoomState({RoomStatus status = RoomStatus.waitingRoom}) {
  return RoomState(
    keeper: 'keeper-1',
    nextSpeaker: const Omittable('user-2'),
    currentSpeaker: const Omittable('user-1'),
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
        testParticipant('user-1'),
        testParticipant('user-2'),
        testParticipant('keeper-1'),
      ],
    ),

    turn: SessionTurnState(roomState: _createRoomState(status: roomStatus)),
  );
}

class FakeSessionController implements SessionController {
  @override
  SessionReactionBuffer? get reactionBuffer => null;
  SessionChatService? _chat;
  @override
  SessionChatService get chat => _chat ??= (() {
    final value = SessionChatService(
      transport: () => transport,
      keeperIdentity: () => state.roomState.keeper,
      isKeeper: isCurrentUserKeeper,
    );
    addTearDown(value.dispose);
    return value;
  })();
  final receivedReactions = <(String, String)>[];
  SessionReactionsService? _reactions;
  @override
  SessionReactionsService get reactions => _reactions ??= (() {
    final value = SessionReactionsService(
      transport: () => transport,
      hasKeeper: () => state.hasKeeper,
      emit: (identity, emoji) async {
        receivedReactions.add((identity, emoji));
        return true;
      },
      onError: (_, _) {},
    );
    addTearDown(value.dispose);
    return value;
  })();
  SessionTransport? mockTransport;
  Room? _bridgedRoom;
  TestRoomTransport? _roomTransport;
  @override
  SessionTransport? get transport {
    if (mockTransport != null) return mockTransport;
    final room = mockRoom;
    if (room == null) return null;
    if (!identical(_bridgedRoom, room)) {
      _bridgedRoom = room;
      final value = TestRoomTransport(
        room,
        extraParticipants: () => state.participantsList,
      );
      _roomTransport = value;
      addTearDown(value.dispose);
    }
    return _roomTransport;
  }

  SessionKeeperController? _keeper;
  @override
  SessionKeeperController get keeper => _keeper ??= _FakeKeeper(
    SessionModerationService(
      backend: _UnusedModerationBackend(),
      state: () => state,
      isKeeper: isCurrentUserKeeper,
      transport: () => transport,
      applyState: applyRoomState,
      prepareRemoval: admission.prepareRemoval,
      markRemoved: markParticipantRemoved,
      leave: disconnectFromRoom,
      onError: (_, _) {},
      captureValidity: () =>
          () => true,
    ),
  );
  @override
  SessionAttempt? activeAttempt;
  @override
  SessionAdmissionService admission = FakeAdmissionService();
  SessionRoomState mockState = _createSessionState();
  SessionDeviceController mockDevices = FakeSessionDeviceController();
  bool disconnectFromRoomCalled = false;
  List<SessionChatMessage> get addedChatMessages => chat.messages;
  bool isCurrentUserKeeperValue = false;
  SessionOptions mockOptions = testSessionOptions;
  Room? mockRoom;
  FakeLocalMedia mockLocalMedia = FakeLocalMedia();
  FakeRoomMedia mockRoomMedia = FakeRoomMedia();

  /// Whether the room's turn rules allow the microphone on at join.
  bool mockShouldEnableMicrophone = true;

  @override
  bool shouldEnableMicrophone() =>
      mockOptions.microphoneEnabled && mockShouldEnableMicrophone;

  @override
  SessionRoomState get state => mockState;
  @override
  SessionRoomState get admissionState => state;

  @override
  void applyRoomState(RoomState roomState) {
    mockState = SessionRoomState(
      connection: mockState.connection,
      participants: mockState.participants,

      turn: SessionTurnState(roomState: roomState),
    );
  }

  @override
  SessionDeviceController get devices => mockDevices;

  @override
  Room? get room => mockRoom;

  @override
  LocalMedia get localMedia => mockLocalMedia;

  @override
  RoomMedia get roomMedia => mockRoomMedia;

  @override
  SessionOptions get options => mockOptions;

  @override
  Future<void> disconnectFromRoom() async {
    disconnectFromRoomCalled = true;
  }

  @override
  void addSessionChatMessage(SessionChatMessage message) {
    chat.add(message);
  }

  @override
  bool isCurrentUserKeeper() {
    return isCurrentUserKeeperValue;
  }

  @override
  void markParticipantRemoved(RemoveReason reason) {}

  Set<String> mediaRecipients = {};
  @override
  void updateAdmittedMediaRecipients(Set<String> identities) {
    mediaRecipients = Set.of(identities);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAdmissionService extends Fake implements SessionAdmissionService {
  @override
  void setApprovalRequired(bool value) {}
  Future<void> Function(String)? onRevoke;
  @override
  bool get busy => false;
  @override
  Set<String> get unresolvedRemovals => const {};
  @override
  Set<String> get admittedIdentities => const {};
  @override
  String? get error => null;
  @override
  KeeperAdmissionController? get keeperController => null;
  @override
  void addListener(void Function() listener) {}
  @override
  void removeListener(void Function() listener) {}
  @override
  void requireRemovalReady() {
    if (onRevoke == null) throw StateError('Admission is not ready');
  }

  @override
  Future<PreparedAdmissionRemoval> prepareRemoval(String identity) async {
    requireRemovalReady();
    return PreparedAdmissionRemoval(
      commit: () => revokeRemovedParticipant(identity),
      reject: () async {},
      unknown: () async {},
    );
  }

  @override
  Future<void> revokeRemovedParticipant(String identity) async {
    await onRevoke!(identity);
  }
}

class _FakeKeeper extends Fake implements SessionKeeperController {
  _FakeKeeper(this.moderation);
  @override
  final SessionModerationService moderation;
}

class _UnusedModerationBackend extends Fake
    implements SessionModerationBackend {}
