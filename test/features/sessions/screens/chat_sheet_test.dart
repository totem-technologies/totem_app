import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../livekit_mocks.dart';

class MockSessionMessagingController extends Mock
    implements SessionMessagingController {}

class _TestMessagesNotifier extends Notifier<List<SessionChatMessage>> {
  _TestMessagesNotifier(this._initial);

  final List<SessionChatMessage> _initial;

  @override
  List<SessionChatMessage> build() => _initial;

  // ignore: use_setters_to_change_properties
  void set(List<SessionChatMessage> value) {
    state = value;
  }
}

class _ChatSheetHarness {
  const _ChatSheetHarness({
    required this.container,
    required this.messagesProvider,
  });

  final ProviderContainer container;
  final NotifierProvider<_TestMessagesNotifier, List<SessionChatMessage>>
  messagesProvider;
}

SessionDetailSchema _createSessionEvent() {
  return SessionDetailSchema(
    slug: 'session-1',
    title: 'Session',
    space: MobileSpaceDetailSchema(
      slug: 'space-1',
      title: 'Space',
      imageLink: null,
      shortDescription: 'A test space.',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime(2024),
        slug: 'keeper-1',
      ),
      category: null,
      subscribers: 0,
      recurring: null,
      price: 0,
      nextEvents: const [],
    ),
    content: '',
    seatsLeft: 10,
    duration: 60,
    start: DateTime(2024, 1, 1, 10),
    attending: true,
    open: true,
    started: true,
    cancelled: false,
    joinable: true,
    ended: false,
    rsvpUrl: '',
    joinUrl: null,
    subscribeUrl: '',
    calLink: '',
    subscribed: false,
    userTimezone: null,
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

SessionRoomState _createSessionState({
  List<SessionChatMessage> messages = const [],
}) {
  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: const ParticipantsState(),
    chat: ChatState(messages: messages),
    turn: const SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: '',
        currentSpeaker: '',
        status: RoomStatus.active,
        turnState: TurnState.idle,
        sessionSlug: 'session-1',
        statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: <String>[],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

void main() {
  Future<void> pumpChatSheet(
    WidgetTester tester, {
    required bool isKeeper,
    required List<SessionChatMessage> messages,
    required SessionController session,
    required AuthState authState,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(authState),
          ),
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionEventProvider.overrideWith(
            (ref) => _createSessionEvent(),
          ),
          currentSessionStateProvider.overrideWithValue(
            _createSessionState(messages: messages),
          ),
          isCurrentUserKeeperProvider.overrideWith((ref) => isKeeper),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SessionChatSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<_ChatSheetHarness> pumpChatSheetWithMutableMessages(
    WidgetTester tester, {
    required bool isKeeper,
    required List<SessionChatMessage> messages,
    required SessionController session,
    required AuthState authState,
  }) async {
    final messagesProvider =
        NotifierProvider<_TestMessagesNotifier, List<SessionChatMessage>>(
          () => _TestMessagesNotifier(messages),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(authState),
          ),
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionEventProvider.overrideWith(
            (ref) => _createSessionEvent(),
          ),
          currentSessionStateProvider.overrideWithValue(
            _createSessionState(messages: messages),
          ),
          isCurrentUserKeeperProvider.overrideWith((ref) => isKeeper),
          sessionMessagesProvider.overrideWith(
            (ref) => ref.watch(messagesProvider),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SessionChatSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionChatSheet)),
      listen: false,
    );

    return _ChatSheetHarness(
      container: container,
      messagesProvider: messagesProvider,
    );
  }

  group('SessionChatSheet', () {
    late MockSessionController session;
    late MockSessionMessagingController messaging;

    setUp(() {
      session = MockSessionController();
      messaging = MockSessionMessagingController();
      when(() => session.messaging).thenReturn(messaging);
      when(() => messaging.sendMessage(any())).thenAnswer((_) async {});
    });

    testWidgets('shows the keeper hint and no composer for non-keeper', (
      tester,
    ) async {
      await pumpChatSheet(
        tester,
        isKeeper: false,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      expect(
        find.text('Only the Keeper can post messages here'),
        findsOneWidget,
      );
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.text('Welcome! 🙏'), findsNothing);
    });

    testWidgets('shows the keeper composer and quick messages', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      expect(find.text('Long press to send a quick message'), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.text('Welcome! 🙏'), findsOneWidget);
      expect(find.text('Please mute your mic'), findsOneWidget);
    });

    testWidgets('renders my messages and other messages', (tester) async {
      final mine = SessionChatMessage(
        id: 'msg-1',
        sender: true,
        message: 'My message',
        timestamp: 1,
        participant: MockLocalParticipant('me@example.com'),
      );
      final other = SessionChatMessage(
        id: 'msg-2',
        sender: false,
        message: 'Their message',
        timestamp: 2,
        participant: MockRemoteParticipant('user-2', 'Other User'),
      );

      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: [mine, other],
        session: session,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'me@example.com',
            name: 'Me',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      expect(find.byType(MyChatBubble), findsOneWidget);
      expect(find.byType(OtherChatBubble), findsOneWidget);
      expect(find.text('My message'), findsOneWidget);
      expect(find.text('Their message'), findsOneWidget);
      expect(find.text('No messages yet'), findsNothing);
    });

    testWidgets('scrolls to the newest message when a new message arrives', (
      tester,
    ) async {
      final messages = List.generate(
        20,
        (index) => SessionChatMessage(
          id: 'msg-$index',
          sender: false,
          message: 'Message $index',
          timestamp: index,
          participant: MockRemoteParticipant('user-$index', 'User $index'),
        ),
      );

      final harness = await pumpChatSheetWithMutableMessages(
        tester,
        isKeeper: false,
        messages: messages,
        session: session,
        authState: AuthState.unauthenticated(),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      final controller = listView.controller!;

      expect(find.text('Message 19'), findsOneWidget);

      controller.jumpTo(0);
      await tester.pumpAndSettle();

      expect(controller.position.pixels, 0);
      expect(find.text('Message 0'), findsOneWidget);

      final updatedMessages = [
        ...messages,
        SessionChatMessage(
          id: 'msg-20',
          sender: false,
          message: 'Newest message',
          timestamp: 20,
          participant: MockRemoteParticipant('user-20', 'User 20'),
        ),
      ];

      harness.container
          .read(harness.messagesProvider.notifier)
          .set(updatedMessages);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.position.pixels, controller.position.maxScrollExtent);
    });

    testWidgets('sends a trimmed message from the composer', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      await tester.enterText(find.byType(TextField), '  Hello chat  ');
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      verify(() => messaging.sendMessage('Hello chat')).called(1);
      expect(find.text('Hello chat'), findsNothing);
    });

    testWidgets('sends a quick message on long press', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      await tester.longPress(find.text('Please mute your mic'));
      await tester.pump();

      verify(() => messaging.sendMessage('Please mute your mic')).called(1);
    });
  });
}
