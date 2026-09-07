import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/shared/widgets/chat/message_bubble.dart';
import 'package:totem_core/shared/widgets/chat/message_input_bar.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
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
        name: 'Heather',
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
    participants: ParticipantsState(
      participants: [
        MockRemoteParticipant('keeper-1', 'Heather'),
        MockRemoteParticipant('lucas', 'Lucas'),
      ],
    ),
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

List<Object?> _sharedOverrides({
  required bool isKeeper,
  required List<SessionChatMessage> messages,
  required SessionController session,
  required AuthState authState,
  RoomScreen currentScreen = RoomScreen.listening,
}) {
  return [
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
    resolveCurrentScreenProvider.overrideWith((ref) => currentScreen),
    userProfileProvider.overrideWith(
      (ref, slug) => Future.value(
        PublicUserSchema(
          slug: slug,
          name: slug == 'keeper-1' ? 'Heather' : 'Mocked User $slug',
          profileAvatarType: ProfileAvatarTypeEnum.td,
          dateCreated: DateTime(2024),
        ),
      ),
    ),
  ];
}

void main() {
  Future<void> pumpChatSheet(
    WidgetTester tester, {
    required bool isKeeper,
    required List<SessionChatMessage> messages,
    required SessionController session,
    required AuthState authState,
    RoomScreen currentScreen = RoomScreen.listening,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _sharedOverrides(
          isKeeper: isKeeper,
          messages: messages,
          session: session,
          authState: authState,
          currentScreen: currentScreen,
        ).cast(),
        child: const MaterialApp(
          home: SessionKeyboardShortcuts(
            child: Scaffold(
              body: SessionChatPanel(),
            ),
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
    RoomScreen currentScreen = RoomScreen.listening,
  }) async {
    final messagesProvider =
        NotifierProvider<_TestMessagesNotifier, List<SessionChatMessage>>(
          () => _TestMessagesNotifier(messages),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._sharedOverrides(
            isKeeper: isKeeper,
            messages: messages,
            session: session,
            authState: authState,
            currentScreen: currentScreen,
          ).cast(),
          sessionMessagesProvider.overrideWith(
            (ref) => ref.watch(messagesProvider),
          ),
        ],
        child: const MaterialApp(
          home: SessionKeyboardShortcuts(
            child: Scaffold(
              body: SessionChatPanel(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionChatPanel)),
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
    late MockSessionDeviceController devices;

    setUp(() {
      session = MockSessionController();
      messaging = MockSessionMessagingController();
      devices = MockSessionDeviceController();
      when(() => session.messaging).thenReturn(messaging);
      when(() => session.devices).thenReturn(devices);
      when(
        () => messaging.sendMessage(
          any(),
          recipientIdentity: any(named: 'recipientIdentity'),
        ),
      ).thenAnswer((_) async {});
      when(() => messaging.sendReaction(any())).thenAnswer((_) async {});
      when(() => devices.enableMicrophone()).thenAnswer((_) async {});
      when(() => devices.disableMicrophone()).thenAnswer((_) async {});
      when(() => devices.enableCamera()).thenAnswer((_) async {});
      when(() => devices.disableCamera()).thenAnswer((_) async {});
      when(() => devices.isMicrophoneEnabled).thenReturn(false);
      when(() => devices.isCameraEnabled).thenReturn(false);
    });

    Future<void> runOnDesktop(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('shows the keeper hint and Message Keeper CTA for non-keeper', (
      tester,
    ) async {
      await pumpChatSheet(
        tester,
        isKeeper: false,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      expect(find.text('Everyone'), findsWidgets);
      expect(
        find.text('Only the Keeper can post messages here'),
        findsOneWidget,
      );
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Message Keeper'), findsOneWidget);
      expect(find.text('Message everyone'), findsOneWidget);
      expect(find.byType(MessageInputBar), findsOneWidget);
    });

    testWidgets('shows the keeper composer for Everyone', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      expect(find.text('Everyone'), findsWidgets);
      expect(find.text('Only you can post messages here'), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Message everyone'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Welcome! 🙏'), findsNothing);
      expect(find.text('Please mute your mic'), findsNothing);
    });

    testWidgets('renders own and received messages as MessageBubbles', (
      tester,
    ) async {
      final mine = SessionChatMessage(
        id: 'msg-1',
        sender: true,
        message: 'My message',
        timestamp: DateTime(2024, 1, 1, 10, 25).millisecondsSinceEpoch,
        participant: MockLocalParticipant('me@example.com'),
      );
      final other = SessionChatMessage(
        id: 'msg-2',
        sender: false,
        message: 'Their message',
        timestamp: DateTime(2024, 1, 1, 10, 34).millisecondsSinceEpoch,
        participant: MockRemoteParticipant('keeper-1', 'Heather'),
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

      expect(find.byType(MessageBubble), findsNWidgets(2));
      expect(find.text('My message'), findsOneWidget);
      expect(find.text('Their message'), findsOneWidget);
      expect(find.text('No messages yet'), findsNothing);
    });

    testWidgets('hides private messages while viewing Everyone', (
      tester,
    ) async {
      const group = SessionChatMessage(
        id: 'group-1',
        sender: true,
        message: 'Welcome everyone',
        timestamp: 1,
      );
      final private = SessionChatMessage(
        id: 'dm-1',
        sender: true,
        message: 'Secret for Lucas',
        timestamp: 2,
        recipientIdentity: 'lucas',
        participant: MockLocalParticipant('keeper-1'),
      );

      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: [group, private],
        session: session,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'keeper@example.com',
            slug: 'keeper-1',
            name: 'Heather',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      expect(find.text('Welcome everyone'), findsOneWidget);
      expect(find.text('Secret for Lucas'), findsNothing);
    });

    testWidgets('participant can open a private keeper thread', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: false,
        messages: const [],
        session: session,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'lucas@example.com',
            slug: 'lucas',
            name: 'Lucas',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      await tester.tap(find.text('Message Keeper'));
      await tester.pumpAndSettle();

      expect(find.text('View Group Messages'), findsOneWidget);
      expect(
        find.text('Only the keeper can see these messages'),
        findsOneWidget,
      );
      expect(find.text('Message Heather'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'I need help');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      verify(
        () => messaging.sendMessage(
          'I need help',
          recipientIdentity: 'keeper-1',
        ),
      ).called(1);
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
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      verify(
        () => messaging.sendMessage(
          'Hello chat',
          recipientIdentity: any(named: 'recipientIdentity'),
        ),
      ).called(1);
      expect(find.text('Hello chat'), findsNothing);
    });

    testWidgets('opens the recipient dropdown from the header', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'keeper@example.com',
            slug: 'keeper-1',
            name: 'Heather',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      await tester.tap(find.text('Everyone').first);
      await tester.pumpAndSettle();

      expect(find.text('Lucas'), findsWidgets);
      expect(find.textContaining('only you can post'), findsOneWidget);

      await tester.tap(find.text('Lucas').last);
      await tester.pumpAndSettle();

      expect(find.text('Message Lucas'), findsOneWidget);
    });

    testWidgets('typing in the composer disables session shortcuts', (
      tester,
    ) async {
      await runOnDesktop(() async {
        await pumpChatSheet(
          tester,
          isKeeper: true,
          messages: const [],
          session: session,
          authState: AuthState.unauthenticated(),
        );

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        verifyNever(() => devices.enableMicrophone());
        verifyNever(() => messaging.sendReaction(any()));
      });
    });
  });
}
