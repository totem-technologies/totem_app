import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_chat_message.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';

RoomState _roomState({
  RoomStatus status = RoomStatus.waitingRoom,
  TurnState turnState = TurnState.idle,
  String keeper = 'keeper',
  String? currentSpeaker,
  String? nextSpeaker,
  String? roundMessage,
}) {
  return RoomState(
    keeper: keeper,
    nextSpeaker: nextSpeaker ?? '',
    currentSpeaker: currentSpeaker ?? '',
    status: status,
    turnState: turnState,
    sessionSlug: 'session-1',
    statusDetail: const RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
    talkingOrder: const [],
    version: 1,
    roundNumber: 1,
    roundMessage: roundMessage,
  );
}

SessionRoomState _state({
  RoomConnectionState connectionState = RoomConnectionState.connecting,
  SessionPhase phase = SessionPhase.connecting,
  RoomError? error,
  RoomStatus roomStatus = RoomStatus.waitingRoom,
  TurnState turnState = TurnState.idle,
  List<Participant> participants = const <Participant>[],
  bool hasKeeperDisconnected = false,
  List<SessionChatMessage> messages = const [],
  String keeper = 'keeper',
  String? currentSpeaker,
  String? nextSpeaker,
  String? roundMessage,
}) {
  return SessionRoomState(
    connection: ConnectionState(
      phase: phase,
      state: connectionState,
      error: error,
    ),
    participants: ParticipantsState(
      participants: participants,
      hasKeeperDisconnected: hasKeeperDisconnected,
    ),
    chat: ChatState(messages: messages),
    turn: SessionTurnState(
      roomState: _roomState(
        status: roomStatus,
        turnState: turnState,
        keeper: keeper,
        currentSpeaker: currentSpeaker,
        nextSpeaker: nextSpeaker,
        roundMessage: roundMessage,
      ),
    ),
  );
}

void main() {
  group('SessionParticipantKeys', () {
    test('returns same key for same identity', () {
      final keys = SessionParticipantKeys();

      final first = keys.getKey('alice');
      final second = keys.getKey('alice');

      expect(identical(first, second), isTrue);
    });

    test('returns different keys for different identities', () {
      final keys = SessionParticipantKeys();

      final alice = keys.getKey('alice');
      final bob = keys.getKey('bob');

      expect(identical(alice, bob), isFalse);
    });
  });

  group('session scope selectors', () {
    test('defaults when scope is not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(currentSessionProvider), isNull);
      expect(container.read(currentSessionStateProvider), isNull);
      expect(
        container.read(connectionStateProvider),
        RoomConnectionState.connecting,
      );
      expect(container.read(sessionPhaseProvider), SessionPhase.connecting);
      expect(container.read(sessionErrorProvider), isNull);
      expect(container.read(roomStatusProvider), RoomStatus.waitingRoom);
      expect(container.read(turnStateProvider), TurnState.idle);
      expect(container.read(sessionParticipantsProvider), isEmpty);
      expect(container.read(sessionMessagesProvider), isEmpty);
      expect(container.read(lastSessionMessageProvider), isNull);
      expect(container.read(hasKeeperDisconnectedProvider), isFalse);
      expect(container.read(hasKeeperProvider), isFalse);
      expect(container.read(featuredParticipantProvider), isNull);
      expect(container.read(speakingNextParticipantProvider), isNull);
      expect(container.read(currentSessionEventProvider), isNull);
      expect(container.read(isCurrentUserKeeperProvider), isFalse);
      expect(container.read(isMyTurnProvider), isFalse);
      expect(container.read(amNextSpeakerProvider), isFalse);
    });

    test('maps livekit and disconnect errors correctly', () {
      final livekitError = RoomLiveKitError(
        ConnectException(
          'livekit failed',
          reason: ConnectionErrorReason.NotAllowed,
        ),
      );
      const disconnectError = RoomDisconnectionError(DisconnectReason.unknown);

      final livekitContainer = ProviderContainer(
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            _state(error: livekitError),
          ),
        ],
      );
      addTearDown(livekitContainer.dispose);

      expect(livekitContainer.read(sessionErrorProvider), livekitError);
      expect(livekitContainer.read(sessionLivekitErrorProvider), isNotNull);
      expect(livekitContainer.read(disconnectionReasonProvider), isNull);

      final disconnectContainer = ProviderContainer(
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            _state(error: disconnectError),
          ),
        ],
      );
      addTearDown(disconnectContainer.dispose);

      expect(disconnectContainer.read(sessionErrorProvider), disconnectError);
      expect(disconnectContainer.read(sessionLivekitErrorProvider), isNull);
      expect(
        disconnectContainer.read(disconnectionReasonProvider),
        DisconnectReason.unknown,
      );
    });

    test('computes selectors from state', () {
      const chatMessage = SessionChatMessage(
        message: 'hello',
        timestamp: 1,
        id: 'm1',
        sender: true,
      );

      final participants = <Participant>[];

      final container = ProviderContainer(
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            _state(
              connectionState: RoomConnectionState.connected,
              phase: SessionPhase.connected,
              roomStatus: RoomStatus.active,
              turnState: TurnState.passing,
              participants: participants,
              hasKeeperDisconnected: true,
              messages: const [chatMessage],
              keeper: 'keeper',
              currentSpeaker: 'alice',
              nextSpeaker: 'keeper',
              roundMessage: 'focus',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(connectionStateProvider),
        RoomConnectionState.connected,
      );
      expect(container.read(sessionPhaseProvider), SessionPhase.connected);
      expect(container.read(roomStatusProvider), RoomStatus.active);
      expect(container.read(turnStateProvider), TurnState.passing);
      expect(container.read(sessionParticipantsProvider), isEmpty);
      expect(container.read(hasKeeperDisconnectedProvider), isTrue);
      expect(container.read(sessionMessagesProvider), hasLength(1));
      expect(container.read(lastSessionMessageProvider)?.id, 'm1');
      expect(container.read(roundMessageProvider), 'focus');
      expect(container.read(hasKeeperProvider), isFalse);
      expect(container.read(featuredParticipantProvider), isNull);
      expect(container.read(speakingNextParticipantProvider), isNull);
    });
  });
}
