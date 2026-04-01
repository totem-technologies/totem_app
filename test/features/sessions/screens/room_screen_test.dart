import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/error_screen.dart';
import 'package:totem_app/features/sessions/screens/my_turn.dart';
import 'package:totem_app/features/sessions/screens/not_my_turn.dart';
import 'package:totem_app/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_app/features/sessions/screens/room_screen.dart';
import 'package:totem_app/features/sessions/screens/session_disconnected.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
import '../livekit_mocks.dart';

MockLocalParticipant _buildMockParticipant(String id) {
  final participant = MockLocalParticipant(id);
  when(
    participant.createListener,
  ).thenReturn(MockParticipantEventsListener());
  when(participant.isMicrophoneEnabled).thenAnswer((_) => false);
  when(participant.isCameraEnabled).thenAnswer((_) => false);
  when(() => participant.getTrackPublicationBySource(any())).thenReturn(null);
  return participant;
}

SessionDetailSchema _createSessionEvent({
  required DateTime start,
  required int duration,
  String slug = 'test-session',
  bool ended = false,
}) {
  return SessionDetailSchema(
    slug: slug,
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
    duration: duration,
    start: start,
    attending: true,
    open: true,
    started: true,
    cancelled: false,
    joinable: true,
    ended: ended,
    rsvpUrl: '',
    joinUrl: null,
    subscribeUrl: '',
    calLink: '',
    subscribed: false,
    userTimezone: null,
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

Future<void> _pumpRoomScreen(
  WidgetTester tester, {
  required SessionDetailSchema event,
  required RoomConnectionState connectionState,
  required RoomStatus roomStatus,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSessionProvider.overrideWith((ref) => null),
        currentSessionEventProvider.overrideWith((ref) => event),
        resolveCurrentScreenProvider.overrideWith((ref) => RoomScreen.loading),
        connectionStateProvider.overrideWith((ref) => connectionState),
        roomStatusProvider.overrideWith((ref) => roomStatus),
        disconnectionReasonProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(
        home: VideoRoomScreen(
          sessionSlug: 'test-session',
          loadingScreen: SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpRoomScreenForResolvedScreen(
  WidgetTester tester, {
  required MockSessionController session,
  required SessionDetailSchema event,
  required RoomScreen screen,
}) async {
  final p1 = _buildMockParticipant('user-1');
  final p2 = _buildMockParticipant('user-2');
  final keeper = _buildMockParticipant('keeper-1');

  final sessionState = SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(
      participants: [
        p1,
        p2,
        keeper,
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
        talkingOrder: [],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.unauthenticated()),
        ),
        currentSessionProvider.overrideWith((ref) => session),
        currentSessionStateProvider.overrideWithValue(sessionState),
        currentSessionEventProvider.overrideWith((ref) => event),
        resolveCurrentScreenProvider.overrideWith((ref) => screen),
        connectionStateProvider.overrideWith(
          (ref) => RoomConnectionState.connected,
        ),
        roomStatusProvider.overrideWith((ref) => RoomStatus.active),
        isCurrentUserKeeperProvider.overrideWith((ref) => false),
        isCameraOnProvider.overrideWith((ref) => false),
        roundMessageProvider.overrideWith((ref) => null),
        sessionMessagesProvider.overrideWith((ref) => const []),
        lastSessionMessageProvider.overrideWith((ref) => null),
        disconnectionReasonProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(
        home: VideoRoomScreen(
          sessionSlug: 'test-session',
          loadingScreen: SizedBox(key: ValueKey('loading-screen')),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _MutableRoomScreenHarness {
  const _MutableRoomScreenHarness({
    required this.container,
    required this.eventProvider,
    required this.connectionStateProvider,
    required this.roomStatusProvider,
  });

  final ProviderContainer container;
  final NotifierProvider<_SessionEventOverrideNotifier, SessionDetailSchema?>
  eventProvider;
  final NotifierProvider<_ConnectionStateOverrideNotifier, RoomConnectionState>
  connectionStateProvider;
  final NotifierProvider<_RoomStatusOverrideNotifier, RoomStatus>
  roomStatusProvider;
}

class _SessionEventOverrideNotifier extends Notifier<SessionDetailSchema?> {
  _SessionEventOverrideNotifier(this._initial);

  final SessionDetailSchema? _initial;

  @override
  SessionDetailSchema? build() => _initial;

  // ignore: use_setters_to_change_properties
  void set(SessionDetailSchema? value) {
    state = value;
  }
}

class _ConnectionStateOverrideNotifier extends Notifier<RoomConnectionState> {
  _ConnectionStateOverrideNotifier(this._initial);

  final RoomConnectionState _initial;

  @override
  RoomConnectionState build() => _initial;

  // ignore: use_setters_to_change_properties
  void set(RoomConnectionState value) {
    state = value;
  }
}

class _RoomStatusOverrideNotifier extends Notifier<RoomStatus> {
  _RoomStatusOverrideNotifier(this._initial);

  final RoomStatus _initial;

  @override
  RoomStatus build() => _initial;

  // ignore: use_setters_to_change_properties
  void set(RoomStatus value) {
    state = value;
  }
}

Future<_MutableRoomScreenHarness> _pumpRoomScreenWithMutableState(
  WidgetTester tester, {
  required SessionDetailSchema event,
  required RoomConnectionState connectionState,
  required RoomStatus roomStatus,
}) async {
  final eventStateProvider =
      NotifierProvider<_SessionEventOverrideNotifier, SessionDetailSchema?>(
        () => _SessionEventOverrideNotifier(event),
      );
  final connectionStateStateProvider =
      NotifierProvider<_ConnectionStateOverrideNotifier, RoomConnectionState>(
        () => _ConnectionStateOverrideNotifier(connectionState),
      );
  final roomStatusStateProvider =
      NotifierProvider<_RoomStatusOverrideNotifier, RoomStatus>(
        () => _RoomStatusOverrideNotifier(roomStatus),
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSessionProvider.overrideWith((ref) => null),
        currentSessionEventProvider.overrideWith(
          (ref) => ref.watch(eventStateProvider),
        ),
        resolveCurrentScreenProvider.overrideWith((ref) => RoomScreen.loading),
        connectionStateProvider.overrideWith(
          (ref) => ref.watch(connectionStateStateProvider),
        ),
        roomStatusProvider.overrideWith(
          (ref) => ref.watch(roomStatusStateProvider),
        ),
        disconnectionReasonProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(
        home: VideoRoomScreen(
          sessionSlug: 'test-session',
          loadingScreen: SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(VideoRoomScreen)),
    listen: false,
  );

  return _MutableRoomScreenHarness(
    container: container,
    eventProvider: eventStateProvider,
    connectionStateProvider: connectionStateStateProvider,
    roomStatusProvider: roomStatusStateProvider,
  );
}

void main() {
  group('VideoRoomScreen - screen rendering', () {
    late MockSessionController session;
    late MockSessionDeviceController devices;

    setUpAll(() {
      registerFallbackValue(TrackSource.camera);
    });

    setUp(() {
      session = MockSessionController();
      devices = MockSessionDeviceController();
      final localParticipant = _buildMockParticipant('user-1');

      when(() => session.room).thenReturn(FakeRoom(localParticipant));
      when(() => session.devices).thenReturn(devices);
      when(() => devices.localVideoTrack).thenReturn(null);
      when(() => session.isCurrentUserKeeper()).thenReturn(false);
      when(() => session.event).thenReturn(
        _createSessionEvent(
          start: DateTime.now().subtract(const Duration(minutes: 5)),
          duration: 10,
        ),
      );
      when(() => session.join()).thenAnswer((_) async {});
    });

    testWidgets('renders loading screen for RoomScreen.loading', (
      tester,
    ) async {
      final event = _createSessionEvent(
        start: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreenForResolvedScreen(
        tester,
        session: session,
        event: event,
        screen: RoomScreen.loading,
      );

      expect(find.byKey(const ValueKey('loading-screen')), findsOneWidget);
    });

    testWidgets('renders disconnected screen for RoomScreen.disconnected', (
      tester,
    ) async {
      final event = _createSessionEvent(
        start: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreenForResolvedScreen(
        tester,
        session: session,
        event: event,
        screen: RoomScreen.disconnected,
      );

      expect(find.byType(SessionDisconnectedScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('renders error screen for RoomScreen.error', (tester) async {
      final event = _createSessionEvent(
        start: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreenForResolvedScreen(
        tester,
        session: session,
        event: event,
        screen: RoomScreen.error,
      );

      expect(find.byType(RoomErrorScreen), findsOneWidget);
    });

    testWidgets('renders receive totem screen for RoomScreen.receiving', (
      tester,
    ) async {
      final event = _createSessionEvent(
        start: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreenForResolvedScreen(
        tester,
        session: session,
        event: event,
        screen: RoomScreen.receiving,
      );

      expect(find.byType(ReceiveTotemScreen), findsOneWidget);
    });

    testWidgets('renders my turn screen for RoomScreen.myTurn', (tester) async {
      final event = _createSessionEvent(
        start: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreenForResolvedScreen(
        tester,
        session: session,
        event: event,
        screen: RoomScreen.myTurn,
      );

      expect(find.byType(MyTurn), findsOneWidget);
    });

    testWidgets('renders my turn screen for RoomScreen.passing', (
      tester,
    ) async {
      final event = _createSessionEvent(
        start: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreenForResolvedScreen(
        tester,
        session: session,
        event: event,
        screen: RoomScreen.passing,
      );

      expect(find.byType(MyTurn), findsOneWidget);
    });

    testWidgets('renders not my turn screen for RoomScreen.notMyTurn', (
      tester,
    ) async {
      final event = _createSessionEvent(
        start: DateTime.now().subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreenForResolvedScreen(
        tester,
        session: session,
        event: event,
        screen: RoomScreen.notMyTurn,
      );

      expect(find.byType(NotMyTurn), findsOneWidget);
    });
  });

  group('VideoRoomScreen - 5 minute warning', () {
    testWidgets('shows the warning popup when 5 minutes remain', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Time Remaining 5 min'), findsOneWidget);
      expect(
        find.text('Thanks for your participation in this session today'),
        findsOneWidget,
      );
    });

    testWidgets('does not show the warning when room is not active', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.waitingRoom,
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Time Remaining 5 min'), findsNothing);
      expect(
        find.text('Thanks for your participation in this session today'),
        findsNothing,
      );
    });

    testWidgets('shows the warning only once for the same session', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time Remaining 5 min'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('Time Remaining 5 min'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time Remaining 5 min'), findsNothing);
    });

    testWidgets(
      'does not re-show warning after room rebuilds for same session slug',
      (tester) async {
        final now = DateTime.now();
        final event = _createSessionEvent(
          slug: 'stable-session',
          start: now.subtract(const Duration(minutes: 9)),
          duration: 10,
        );

        final harness = await _pumpRoomScreenWithMutableState(
          tester,
          event: event,
          connectionState: RoomConnectionState.connected,
          roomStatus: RoomStatus.active,
        );

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Time Remaining 5 min'), findsOneWidget);

        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        expect(find.text('Time Remaining 5 min'), findsNothing);

        harness.container
            .read(harness.roomStatusProvider.notifier)
            .set(RoomStatus.waitingRoom);
        await tester.pump();
        harness.container
            .read(harness.roomStatusProvider.notifier)
            .set(RoomStatus.active);
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('Time Remaining 5 min'), findsNothing);
      },
    );

    testWidgets('schedules warning and shows it only after threshold', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 2)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(minutes: 2, seconds: 50));
      expect(find.text('Time Remaining 5 min'), findsNothing);

      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Time Remaining 5 min'), findsOneWidget);
    });

    testWidgets('shows warning immediately when threshold already passed', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 9)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time Remaining 5 min'), findsOneWidget);
    });

    testWidgets('does not show warning when event has ended', (tester) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 9)),
        duration: 10,
        ended: true,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Time Remaining 5 min'), findsNothing);
    });

    testWidgets('cancels scheduled warning when connection disconnects', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 4)),
        duration: 10,
      );

      final harness = await _pumpRoomScreenWithMutableState(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Time Remaining 5 min'), findsNothing);

      harness.container
          .read(harness.connectionStateProvider.notifier)
          .set(RoomConnectionState.disconnected);
      await tester.pump();

      await tester.pump(const Duration(seconds: 45));
      expect(find.text('Time Remaining 5 min'), findsNothing);
    });

    testWidgets('cancels scheduled warning when room ends before threshold', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 4)),
        duration: 10,
      );

      final harness = await _pumpRoomScreenWithMutableState(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Time Remaining 5 min'), findsNothing);

      harness.container
          .read(harness.roomStatusProvider.notifier)
          .set(RoomStatus.ended);
      await tester.pump();

      await tester.pump(const Duration(seconds: 45));
      expect(find.text('Time Remaining 5 min'), findsNothing);
    });

    testWidgets('resets one-shot guard when session slug changes', (
      tester,
    ) async {
      final now = DateTime.now();
      final eventA = _createSessionEvent(
        slug: 'session-a',
        start: now.subtract(const Duration(minutes: 9)),
        duration: 10,
      );

      final harness = await _pumpRoomScreenWithMutableState(
        tester,
        event: eventA,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time Remaining 5 min'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('Time Remaining 5 min'), findsNothing);

      final eventB = _createSessionEvent(
        slug: 'session-b',
        start: DateTime.now().subtract(const Duration(minutes: 9)),
        duration: 10,
      );

      harness.container.read(harness.eventProvider.notifier).set(eventB);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Time Remaining 5 min'), findsOneWidget);
    });
  });
}
