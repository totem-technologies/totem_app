import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart'
    show RoomScreen;
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

import '../controllers/core/session_controller_mock.dart';
import '../livekit_mocks.dart';

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
  List<SessionChatMessage> messages = const [],
  String keeper = 'keeper',
  String? currentSpeaker,
  String? nextSpeaker,
  String? roundMessage,
  bool wasJoining = false,
}) {
  return SessionRoomState(
    connection: ConnectionState(
      phase: phase,
      state: connectionState,
      error: error,
      wasJoining: wasJoining,
    ),
    participants: ParticipantsState(participants: participants),
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
    SessionOptions options(String slug) => SessionOptions(
      sessionSlug: slug,
      token: 'token',
      cameraEnabled: true,
      microphoneEnabled: true,
      speakerEnabled: true,
      cameraOptions: const CameraCaptureOptions(),
    );

    test('returns same key for same identity', () {
      final keys = SessionParticipantKeys();

      final first = keys.getKey('alice');
      final second = keys.getKey('alice');

      check(identical(first, second)).equals(true);
    });

    test('returns different keys for different identities', () {
      final keys = SessionParticipantKeys();

      final alice = keys.getKey('alice');
      final bob = keys.getKey('bob');

      check(identical(alice, bob)).equals(false);
    });

    test('recreates keys when the session scope changes', () {
      final container = ProviderContainer(
        overrides: [sessionScopeProvider.overrideWithValue(options('first'))],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        sessionParticipantKeysProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final first = subscription.read().getKey('alice');

      container.updateOverrides([
        sessionScopeProvider.overrideWithValue(options('second')),
      ]);

      final second = subscription.read().getKey('alice');
      check(identical(first, second)).isFalse();
    });
  });

  group('session chat unread threads', () {
    test('persists unread threads until the visible panel marks them read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller =
          container.read(sessionChatUnreadThreadsProvider.notifier)
            ..markUnread('lucas')
            ..markUnread(null);

      check(container.read(sessionChatUnreadThreadsProvider)).contains('lucas');
      check(container.read(sessionChatUnreadThreadsProvider)).contains(null);
      final everyoneUnread = controller.latestUnreadThread;
      check(everyoneUnread).isNotNull();
      check(everyoneUnread?.thread).isNull();

      controller.markRead(null);

      check(container.read(sessionChatUnreadThreadsProvider)).contains('lucas');
      check(
        container.read(sessionChatUnreadThreadsProvider).contains(null),
      ).isFalse();
      check(controller.latestUnreadThread?.thread).equals('lucas');

      controller.markRead('lucas');

      check(controller.latestUnreadThread).isNull();
    });
  });

  group('session scope selectors', () {
    test('participant projections ignore chat-only changes', () {
      final participant = MockRemoteParticipant('alice', 'Alice');
      final before = _state(participants: [participant]);
      final after = SessionRoomState(
        connection: before.connection,
        participants: before.participants,
        turn: before.turn,
        chat: const ChatState(
          messages: [
            SessionChatMessage(
              message: 'Hello',
              timestamp: 1,
              id: 'message-1',
              sender: false,
            ),
          ],
        ),
      );

      check(
        sessionParticipantPresentation(before, participant.identity),
      ).equals(sessionParticipantPresentation(after, participant.identity));
      check(
        sessionParticipantLayout(before),
      ).equals(sessionParticipantLayout(after));
    });

    test('defaults when scope is not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      check(container.read(currentSessionProvider)).isNull();
      check(container.read(currentSessionStateProvider)).isNull();
      check(
        container.read(connectionStateProvider),
      ).equals(RoomConnectionState.connecting);
      check(
        container.read(sessionPhaseProvider),
      ).equals(SessionPhase.connecting);
      check(container.read(sessionErrorProvider)).isNull();
      check(container.read(roomStatusProvider)).equals(RoomStatus.waitingRoom);
      check(container.read(turnStateProvider)).equals(TurnState.idle);
      check(container.read(sessionParticipantsProvider)).isEmpty();
      check(container.read(sessionMessagesProvider)).isEmpty();
      check(container.read(lastSessionMessageProvider)).isNull();
      check(container.read(hasKeeperDisconnectedProvider)).equals(false);
      check(container.read(hasKeeperProvider)).equals(false);
      check(container.read(featuredParticipantProvider)).isNull();
      check(container.read(speakingNextParticipantProvider)).isNull();
      check(container.read(currentSessionEventProvider)).isNull();
      check(container.read(isCurrentUserKeeperProvider)).equals(false);
      check(container.read(isMyTurnProvider)).equals(false);
      check(container.read(amNextSpeakerProvider)).equals(false);
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

      check(livekitContainer.read(sessionErrorProvider)).equals(livekitError);
      check(livekitContainer.read(sessionLivekitErrorProvider)).isNotNull();
      check(livekitContainer.read(disconnectionReasonProvider)).isNull();

      final disconnectContainer = ProviderContainer(
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            _state(error: disconnectError),
          ),
        ],
      );
      addTearDown(disconnectContainer.dispose);

      check(
        disconnectContainer.read(sessionErrorProvider),
      ).equals(disconnectError);
      check(disconnectContainer.read(sessionLivekitErrorProvider)).isNull();
      check(
        disconnectContainer.read(disconnectionReasonProvider),
      ).equals(DisconnectReason.unknown);
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

      check(
        container.read(connectionStateProvider),
      ).equals(RoomConnectionState.connected);
      check(
        container.read(sessionPhaseProvider),
      ).equals(SessionPhase.connected);
      check(container.read(roomStatusProvider)).equals(RoomStatus.active);
      check(container.read(turnStateProvider)).equals(TurnState.passing);
      check(container.read(sessionParticipantsProvider)).isEmpty();
      check(container.read(hasKeeperDisconnectedProvider)).equals(true);
      check(container.read(sessionMessagesProvider)).length.equals(1);
      check(container.read(lastSessionMessageProvider)?.id).equals('m1');
      check(container.read(roundMessageProvider)).equals('focus');
      check(container.read(hasKeeperProvider)).equals(false);
      check(container.read(featuredParticipantProvider)).isNull();
      check(container.read(speakingNextParticipantProvider)).isNull();
    });

    test('computes active session properties correctly', () {
      final alice = MockLocalParticipant('alice');
      final bob = MockLocalParticipant('bob');
      final keeperParticipant = MockLocalParticipant('keeper');

      final participants = [alice, bob, keeperParticipant];

      final fakeSession = FakeSessionController()
        ..mockRoom = FakeRoom(alice)
        ..isCurrentUserKeeperValue = true;

      final container = ProviderContainer(
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            _state(
              connectionState: RoomConnectionState.connected,
              phase: SessionPhase.connected,
              roomStatus: RoomStatus.waitingRoom,
              turnState: TurnState.idle,
              participants: participants,
              keeper: 'keeper',
              currentSpeaker: 'keeper',
              nextSpeaker: 'alice',
            ),
          ),
          currentSessionProvider.overrideWithValue(fakeSession),
        ],
      );
      addTearDown(container.dispose);

      check(container.read(hasKeeperProvider)).equals(true);
      check(
        container.read(featuredParticipantProvider)?.identity,
      ).equals('keeper');
      check(
        container.read(speakingNextParticipantProvider)?.identity,
      ).equals('alice');

      check(container.read(isCurrentUserKeeperProvider)).equals(true);
      check(container.read(isMyTurnProvider)).equals(false);
      check(container.read(amNextSpeakerProvider)).equals(true);
      check(
        container.read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.listening);
    });

    test('resolveCurrentScreen resolves different states', () {
      final alice = MockLocalParticipant('alice');
      final fakeSession = FakeSessionController();

      ProviderContainer containerForState(
        RoomConnectionState connState,
        RoomStatus status,
        TurnState turnState,
        String? currentSpeaker,
        String? nextSpeaker, {
        bool noRoom = false,
        bool noLocalParticipant = false,
        RoomError? error,
        bool wasJoining = false,
      }) {
        if (noRoom) {
          fakeSession.mockRoom = null;
        } else if (noLocalParticipant) {
          fakeSession.mockRoom = FakeRoom(MockLocalParticipant('other'));
        } else {
          fakeSession.mockRoom = FakeRoom(alice);
        }

        final container = ProviderContainer(
          overrides: [
            connectionStateProvider.overrideWithValue(connState),
            currentSessionStateProvider.overrideWithValue(
              _state(
                connectionState: connState,
                error: error,
                roomStatus: status,
                turnState: turnState,
                participants: [alice],
                keeper: 'keeper',
                currentSpeaker: currentSpeaker,
                nextSpeaker: nextSpeaker,
                wasJoining: wasJoining,
              ),
            ),
            currentSessionProvider.overrideWithValue(fakeSession),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      // No room -> disconnected
      check(
        containerForState(
          RoomConnectionState.connected,
          RoomStatus.active,
          TurnState.idle,
          'alice',
          'alice',
          noRoom: true,
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.disconnected);

      // error -> RoomScreen.error
      check(
        containerForState(
          RoomConnectionState.error,
          RoomStatus.active,
          TurnState.idle,
          'alice',
          'alice',
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.error);

      // loading -> RoomScreen.loading
      check(
        containerForState(
          RoomConnectionState.connecting,
          RoomStatus.active,
          TurnState.idle,
          'alice',
          'alice',
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.loading);

      // connecting without room (fast-join race) -> RoomScreen.loading
      check(
        containerForState(
          RoomConnectionState.connecting,
          RoomStatus.active,
          TurnState.idle,
          'alice',
          'alice',
          noRoom: true,
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.loading);

      // Transient disconnect
      // disconnected -> RoomScreen.loading
      check(
        containerForState(
          RoomConnectionState.disconnected,
          RoomStatus.waitingRoom,
          TurnState.idle,
          'alice',
          'alice',
          wasJoining: true,
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.loading);

      // disconnected with join-failure -> RoomScreen.loading
      check(
        containerForState(
          RoomConnectionState.disconnected,
          RoomStatus.waitingRoom,
          TurnState.idle,
          'alice',
          'alice',
          error: const RoomDisconnectionError(DisconnectReason.joinFailure),
          wasJoining: true,
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.loading);

      // disconnected with clientInitiated -> RoomScreen.loading
      check(
        containerForState(
          RoomConnectionState.disconnected,
          RoomStatus.waitingRoom,
          TurnState.idle,
          'alice',
          'alice',
          error: const RoomDisconnectionError(DisconnectReason.clientInitiated),
          wasJoining: true,
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.loading);

      // connected, RoomStatus.ended -> RoomScreen.disconnected
      check(
        containerForState(
          RoomConnectionState.connected,
          RoomStatus.ended,
          TurnState.idle,
          'alice',
          'alice',
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.disconnected);

      // Waiting rooms never show turn-taking controls, even when stale room
      // metadata names the local participant as current or next speaker.
      check(
        containerForState(
          RoomConnectionState.connected,
          RoomStatus.waitingRoom,
          TurnState.passing,
          'alice',
          'alice',
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.listening);

      // TurnState.passing and amNextSpeaker -> RoomScreen.receiving
      check(
        containerForState(
          RoomConnectionState.connected,
          RoomStatus.active,
          TurnState.passing,
          'keeper',
          'alice',
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.receiving);

      // My turn
      check(
        containerForState(
          RoomConnectionState.connected,
          RoomStatus.active,
          TurnState.idle,
          'alice',
          'keeper',
        ).read(resolveCurrentScreenProvider),
      ).equals(RoomScreen.speaking);
    });
  });
}
