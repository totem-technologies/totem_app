import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
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
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';

import '../../../../auth/controllers/auth_controller_mock.dart';
import '../../../permissions/fake_media_permission_adapter.dart';
import '../../controllers/core/session_controller_mock.dart';
import '../../controllers/features/session_device_controller_mock.dart';
import '../../livekit_mocks.dart';
import '../../media/test_participants.dart';

class _TestLastMessageNotifier extends Notifier<SessionChatMessage?> {
  @override
  SessionChatMessage? build() => null;

  // ignore: use_setters_to_change_properties
  void set(SessionChatMessage? message) {
    state = message;
  }
}

SessionRoomState _createSessionState() {
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

    turn: const SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: Omittable('user-2'),
        currentSpeaker: Omittable('user-1'),
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
    title: 'Test session',
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
  void autoSizeTest(String description, AsyncValueSetter<WidgetTester> body) {
    testWidgets(
      description,
      (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
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
      when(
        () => deviceController.turnOn(MediaKind.camera),
      ).thenAnswer((_) async => const TurnedOn());
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
      bool isStaff = false,
      FakeMediaPermissionAdapter? adapter,
      bool hasSession = true,
      bool hasIdentity = true,
    }) async {
      final authState = isStaff
          ? AuthState.authenticated(
              user: UserSchema(
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                email: 'staff@example.com',
                dateCreated: DateTime(2024),
                isStaff: true,
              ),
            )
          : AuthState.unauthenticated();
      await pumpWidget(
        tester,
        child: const SessionActionBar(),
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(authState),
          ),
          currentSessionProvider.overrideWith(
            (ref) => hasSession ? session : null,
          ),
          localParticipantIdentityProvider.overrideWith(
            (ref) => hasIdentity ? 'user-2' : null,
          ),
          lastSessionMessageProvider.overrideWith(
            (ref) => ref.watch(_testLastMessageProvider),
          ),
          sessionMessagesProvider.overrideWith((ref) => const []),
          currentSessionStateProvider.overrideWith(
            (ref) => _createSessionState(),
          ),
          isCurrentUserKeeperProvider.overrideWith((ref) => false),
          resolveCurrentScreenProvider.overrideWith((ref) => screen),
          platformInfoProvider.overrideWithValue(const IosApp()),
          mediaPermissionAdapterProvider.overrideWithValue(
            adapter ?? FakeMediaPermissionAdapter(),
          ),
        ],
      );
    }

    /// Taps the microphone, confirming the unmute when another participant
    /// has the totem.
    Future<void> tapMicrophone(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel(RegExp('^Microphone (on|off)')));
      await tester.pumpAndSettle();
      if (find.text('Unmute Anyway').evaluate().isNotEmpty) {
        await tester.tap(find.text('Unmute Anyway'));
        await tester.pumpAndSettle();
      }
    }

    autoSizeTest('session actions are unavailable before a usable connection', (
      tester,
    ) async {
      for (final scenario in [
        (screen: RoomScreen.loading, session: true, identity: true),
        (screen: RoomScreen.disconnected, session: true, identity: true),
        (screen: RoomScreen.error, session: true, identity: true),
        (screen: RoomScreen.listening, session: false, identity: true),
        (screen: RoomScreen.listening, session: true, identity: false),
      ]) {
        await pumpSessionActionBar(
          tester,
          screen: scenario.screen,
          hasSession: scenario.session,
          hasIdentity: scenario.identity,
        );
        await tester.pump();
        for (final label in ['Microphone on', 'Chat', 'Send reaction']) {
          check(find.bySemanticsLabel(label).evaluate()).isEmpty();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    autoSizeTest(
      'confirms before unmuting when another participant has the Totem',
      (tester) async {
        session.mockLocalMedia
          ..hasMicrophoneTrack = true
          ..isMicrophoneEnabled = true;
        await pumpSessionActionBar(tester, screen: RoomScreen.listening);

        await tester.tap(find.bySemanticsLabel(RegExp('^Microphone (on|off)')));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(RegExp('^Microphone (on|off)')));
        await tester.pumpAndSettle();

        check(tester.widgetList(find.text('Stay Muted'))).length.equals(1);

        await tester.tap(find.text('Stay Muted'));
        await tester.pumpAndSettle();
        // Muted by the first tap, and never unmuted.
        check(session.mockLocalMedia.microphoneCommands).deepEquals([false]);
      },
    );

    autoSizeTest('the microphone asks for access, then unmutes', (
      tester,
    ) async {
      session.mockLocalMedia.hasMicrophoneTrack = true;
      final adapter = FakeMediaPermissionAdapter(
        microphone: MediaPermission.unknown,
        requestResults: {MediaKind.microphone: MediaPermission.granted},
      );
      await pumpSessionActionBar(
        tester,
        screen: RoomScreen.listening,
        adapter: adapter,
      );
      await tester.pumpAndSettle();

      await tapMicrophone(tester);

      check(adapter.requested).deepEquals([MediaKind.microphone]);
      check(session.mockLocalMedia.microphoneCommands).deepEquals([true]);
    });

    autoSizeTest('a blocked microphone offers recovery without unmuting', (
      tester,
    ) async {
      session.mockLocalMedia.hasMicrophoneTrack = true;
      final adapter = FakeMediaPermissionAdapter(
        microphone: MediaPermission.blocked,
      );
      await pumpSessionActionBar(
        tester,
        screen: RoomScreen.listening,
        adapter: adapter,
      );
      await tester.pumpAndSettle();

      await tapMicrophone(tester);

      check(session.mockLocalMedia.microphoneCommands).isEmpty();
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      check(adapter.settingsOpened).equals(1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      check(find.text('Close').evaluate()).isEmpty();
      check(session.mockLocalMedia.microphoneCommands).isEmpty();
    });

    autoSizeTest(
      'shows the microphone on the receiving screen only for staff',
      (tester) async {
        for (final isStaff in [false, true]) {
          await pumpSessionActionBar(
            tester,
            screen: RoomScreen.receiving,
            isStaff: isStaff,
          );

          check(
            tester.widgetList(
              find.bySemanticsLabel(RegExp('^Microphone (on|off)')),
            ),
          ).length.equals(isStaff ? 1 : 0);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );

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
          find.bySemanticsLabel('Send reaction').evaluate(),
        ).length.equals(scenario.showsReactions ? 1 : 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    autoSizeTest(
      'More opens leave confirmation and cancellation keeps the session',
      (tester) async {
        await pumpSessionActionBar(tester, screen: RoomScreen.listening);
        await tester.pumpAndSettle();
        final moreLabel = MaterialLocalizations.of(
          tester.element(find.byType(SessionActionBar)),
        ).moreButtonTooltip;
        await tester.tap(find.bySemanticsLabel(moreLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leave session'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        verifyNever(session.leave);
        check(
          find.bySemanticsLabel('Chat').hitTestable().evaluate(),
        ).length.equals(1);
      },
    );

    autoSizeTest('unread chat notifications and Chat select the shared panel', (
      tester,
    ) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.listening);
      final context = tester.element(find.byType(SessionActionBar));
      final container = ProviderScope.containerOf(context, listen: false);
      check(container.read(sessionChatUnreadThreadsProvider)).isEmpty();
      for (final fromNotification in [true, false]) {
        final message = fromNotification
            ? 'Read this notification'
            : 'Open this chat';
        container
            .read(_testLastMessageProvider.notifier)
            .set(
              SessionChatMessage(
                id: fromNotification ? 'notification' : 'chat-button',
                sender: false,
                message: message,
                timestamp: fromNotification ? 1 : 2,
              ),
            );
        await tester.pump();
        check(container.read(sessionChatUnreadThreadsProvider)).contains(null);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(
          fromNotification ? find.text(message) : find.bySemanticsLabel('Chat'),
        );
        await tester.pumpAndSettle();
        check(
          container.read(sessionPresentationProvider).panel,
        ).equals(SessionPanel.chat);
        check(container.read(sessionChatThreadTargetProvider)).isNull();
        check(find.text(message).evaluate()).isEmpty();
        // Only the room-owned panel marks its visible thread read.
        container
            .read(sessionChatUnreadThreadsProvider.notifier)
            .markRead(null);
        await tester.pump();
        check(container.read(sessionChatUnreadThreadsProvider)).isEmpty();
        await tester.tap(find.bySemanticsLabel('Chat'));
        await tester.pump();
        check(
          container.read(sessionPresentationProvider).panel,
        ).equals(SessionPanel.none);
      }
    });
  });
}
