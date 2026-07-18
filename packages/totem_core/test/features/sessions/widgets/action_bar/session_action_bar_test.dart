import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/screens/more_options_popup.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_emoji_button.dart';

import '../../../../auth/controllers/auth_controller_mock.dart';
import '../../controllers/core/session_controller_mock.dart';
import '../../controllers/features/session_device_controller_mock.dart';
import '../../livekit_mocks.dart';

class _TestLastMessageNotifier extends Notifier<SessionChatMessage?> {
  @override
  SessionChatMessage? build() => null;

  // ignore: use_setters_to_change_properties
  void set(SessionChatMessage? message) {
    state = message;
  }
}

class _MockRoom extends Mock implements Room {}

SessionRoomState _createSessionState() {
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
    turn: const SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: 'user-2',
        currentSpeaker: 'user-1',
        status: RoomStatus.active,
        turnState: TurnState.idle,
        sessionSlug: 'test-session',
        statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: ['keeper-1', 'user-1', 'user-2'],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

SessionDetailSchema _createSessionEvent() {
  return SessionDetailSchema(
    slug: 'test-session',
    title: 'Test Session',
    space: MobileSpaceDetailSchema(
      slug: 'test-space',
      title: 'Test Space',
      imageLink: null,
      shortDescription: 'A test space.',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime(2024),
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

final _testLastMessageProvider =
    NotifierProvider<_TestLastMessageNotifier, SessionChatMessage?>(
      _TestLastMessageNotifier.new,
    );

void main() {
  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    List<Object?> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('SessionActionBar', () {
    late MockSessionController session;
    late FakeRoom room;
    late MockLocalParticipant participant;
    late MockSessionDeviceController deviceController;

    setUp(() {
      session = MockSessionController();
      deviceController = MockSessionDeviceController();
      participant = MockLocalParticipant();
      room = FakeRoom(participant);

      when(() => session.room).thenReturn(room);
      when(() => session.devices).thenReturn(deviceController);
      when(() => deviceController.isCameraEnabled).thenReturn(false);
      when(() => deviceController.selectedCameraDeviceId).thenReturn(null);
      when(() => deviceController.localVideoTrack).thenReturn(null);
      when(
        () => deviceController.enableCamera(),
      ).thenAnswer((_) => Future<void>.value());
      when(
        () => deviceController.disableCamera(),
      ).thenAnswer((_) => Future<void>.value());

      when(
        () => participant.getTrackPublicationBySource(TrackSource.microphone),
      ).thenReturn(null);
      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(null);
      when(() => participant.isMicrophoneEnabled()).thenReturn(false);

      when(() => session.isCurrentUserKeeper()).thenReturn(false);
      when(() => session.event).thenReturn(_createSessionEvent());
    });

    Future<void> pumpSessionActionBar(
      WidgetTester tester, {
      required RoomScreen screen,
    }) async {
      await pumpWidget(
        tester,
        child: const SessionActionBar(),
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          currentSessionProvider.overrideWith((ref) => session),
          lastSessionMessageProvider.overrideWith(
            (ref) => ref.watch(_testLastMessageProvider),
          ),
          sessionMessagesProvider.overrideWith((ref) => const []),
          currentSessionStateProvider.overrideWith(
            (ref) => _createSessionState(),
          ),
          isCurrentUserKeeperProvider.overrideWith((ref) => false),
          resolveCurrentScreenProvider.overrideWith((ref) => screen),
        ],
      );
    }

    Finder findPendingBadge() {
      return find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == AppTheme.green &&
            decoration.shape == BoxShape.circle;
      });
    }

    testWidgets('is hidden on loading, disconnected, and error screens', (
      tester,
    ) async {
      for (final screen in [
        RoomScreen.loading,
        RoomScreen.disconnected,
        RoomScreen.error,
      ]) {
        await pumpSessionActionBar(tester, screen: screen);
        await tester.pump();

        expect(find.byType(ActionBar), findsNothing);
      }
    });

    testWidgets('shows expected controls on not-my-turn screen', (
      tester,
    ) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pump();

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.byType(ActionBarButton), findsNWidgets(4));
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(SessionActionBarCameraButton), findsOneWidget);
    });

    testWidgets('shows expected controls on my-turn screen', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.speaking);
      await tester.pump();

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.byType(ActionBarButton), findsNWidgets(3));
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('shows emoji button on listening screen', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pumpAndSettle();
      expect(find.byType(ActionBarEmojiButton), findsOneWidget);
    });

    testWidgets('hides emoji button on speaking screen', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.speaking);
      await tester.pumpAndSettle();
      expect(find.byType(ActionBarEmojiButton), findsNothing);
    });

    testWidgets('hides emoji button on passing screen', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.passing);
      await tester.pumpAndSettle();
      expect(find.byType(ActionBarEmojiButton), findsNothing);
    });

    testWidgets('hides emoji button on receiving screen', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.receiving);
      await tester.pumpAndSettle();
      expect(find.byType(ActionBarEmojiButton), findsNothing);
    });

    testWidgets('returns empty widget when session is null', (tester) async {
      await pumpWidget(
        tester,
        child: const SessionActionBar(),
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          currentSessionProvider.overrideWith((ref) => null),
          resolveCurrentScreenProvider.overrideWith(
            (ref) => RoomScreen.listening,
          ),
        ],
      );

      await tester.pump();
      expect(find.byType(ActionBar), findsNothing);
    });

    testWidgets('returns empty widget when local participant is null', (
      tester,
    ) async {
      final roomWithoutUser = _MockRoom();
      when(() => roomWithoutUser.localParticipant).thenReturn(null);
      when(() => session.room).thenReturn(roomWithoutUser);

      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pump();

      expect(find.byType(ActionBar), findsNothing);
    });

    testWidgets('opens options sheet when tapping more button', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(MoreOptions), findsOneWidget);
    });

    testWidgets('shows pending badge and notification on new chat message', (
      tester,
    ) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pump();

      expect(findPendingBadge(), findsNothing);

      final context = tester.element(find.byType(SessionActionBar));
      final container = ProviderScope.containerOf(context, listen: false);
      container
          .read(_testLastMessageProvider.notifier)
          .set(
            const SessionChatMessage(
              id: 'msg-1',
              sender: false,
              message: 'hello from chat',
              timestamp: 1,
            ),
          );

      await tester.pump();

      expect(findPendingBadge(), findsOneWidget);
      expect(find.text('New message'), findsOneWidget);
      expect(find.text('hello from chat'), findsOneWidget);
    });

    testWidgets('opens chat sheet and clears pending badge', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pump();

      final context = tester.element(find.byType(SessionActionBar));
      final container = ProviderScope.containerOf(context, listen: false);
      container
          .read(_testLastMessageProvider.notifier)
          .set(
            const SessionChatMessage(
              id: 'msg-2',
              sender: false,
              message: 'open chat now',
              timestamp: 2,
            ),
          );
      await tester.pump();

      expect(findPendingBadge(), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Chat'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionChatMessages), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(findPendingBadge(), findsNothing);

      Navigator.of(
        tester.element(find.byType(SessionActionBar)),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SessionChatMessages), findsNothing);
      expect(findPendingBadge(), findsNothing);
    });
  });
}
