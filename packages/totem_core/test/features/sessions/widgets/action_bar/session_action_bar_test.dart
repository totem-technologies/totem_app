import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:material_ui/material_ui.dart' hide ConnectionState;
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
  void autoSizeTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(
      description,
      body,
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );
  }

  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    List<Object?> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              // Production pins the bar to the bottom; without this the
              // scaffold stretches the bar and LayoutBuilder sees full width.
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
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
      when(() => session.state).thenReturn(_createSessionState());
      when(() => session.options).thenReturn(
        const SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          speakerEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
        ),
      );
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
      when(() => participant.isCameraEnabled()).thenReturn(false);

      when(() => session.isCurrentUserKeeper()).thenReturn(false);
      when(() => session.session).thenReturn(_createSessionEvent());
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

    autoSizeTest('is hidden on loading, disconnected, and error screens', (
      tester,
    ) async {
      for (final screen in [
        RoomScreen.loading,
        RoomScreen.disconnected,
        RoomScreen.error,
      ]) {
        await pumpSessionActionBar(tester, screen: screen);
        await tester.pump();

        check(tester.widgetList(find.byType(ActionBar))).length.equals(0);
      }
    });

    autoSizeTest('offers reactions only while listening', (tester) async {
      for (final scenario in [
        (screen: RoomScreen.listening, showsReactions: true),
        (screen: RoomScreen.speaking, showsReactions: false),
        (screen: RoomScreen.passing, showsReactions: false),
        (screen: RoomScreen.receiving, showsReactions: false),
      ]) {
        await pumpSessionActionBar(tester, screen: scenario.screen);
        await tester.pumpAndSettle();

        check(
          tester.widgetList(find.byType(ActionBarEmojiButton)),
        ).length.equals(scenario.showsReactions ? 1 : 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    autoSizeTest('returns empty widget when session is null', (tester) async {
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
      check(tester.widgetList(find.byType(ActionBar))).length.equals(0);
    });

    autoSizeTest('returns empty widget when local participant is null', (
      tester,
    ) async {
      final roomWithoutUser = _MockRoom();
      when(() => roomWithoutUser.localParticipant).thenReturn(null);
      when(() => session.room).thenReturn(roomWithoutUser);

      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pump();

      check(tester.widgetList(find.byType(ActionBar))).length.equals(0);
    });

    autoSizeTest('disables more when session state is missing', (tester) async {
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
          currentSessionStateProvider.overrideWith((ref) => null),
          isCurrentUserKeeperProvider.overrideWith((ref) => false),
          resolveCurrentScreenProvider.overrideWith(
            (ref) => RoomScreen.listening,
          ),
        ],
      );
      await tester.pumpAndSettle();

      final moreLabel = MaterialLocalizations.of(
        tester.element(find.byType(SessionActionBar)),
      ).moreButtonTooltip;
      final moreButton = find.descendant(
        of: find.byTooltip(moreLabel),
        matching: find.byType(ActionBarButton),
      );
      check(tester.widgetList(moreButton)).length.equals(1);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(MoreOptions))).isEmpty();
    });

    autoSizeTest('opens options sheet when tapping more button', (
      tester,
    ) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel(
          MaterialLocalizations.of(
            tester.element(find.byType(SessionActionBar)),
          ).moreButtonTooltip,
        ),
      );
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(MoreOptions))).length.equals(1);
    });

    autoSizeTest('shows pending badge and notification on new chat message', (
      tester,
    ) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      await tester.pump();

      check(tester.widgetList(findPendingBadge())).length.equals(0);

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

      check(tester.widgetList(findPendingBadge())).length.equals(1);
      check(
        tester.widgetList(find.text('New message from Keeper')),
      ).length.equals(1);
      check(tester.widgetList(find.text('hello from chat'))).length.equals(1);
    });

    autoSizeTest('opens chat sheet and clears pending badge', (tester) async {
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

      check(tester.widgetList(findPendingBadge())).length.equals(1);

      await tester.tap(find.bySemanticsLabel('Chat'));
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(SessionChatPanel))).length.equals(1);
      check(tester.widgetList(find.text('No messages yet'))).length.equals(1);
      check(tester.widgetList(findPendingBadge())).length.equals(0);

      Navigator.of(
        tester.element(find.byType(SessionActionBar)),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(SessionChatPanel))).length.equals(0);
      check(tester.widgetList(findPendingBadge())).length.equals(0);
    });
  });
}
