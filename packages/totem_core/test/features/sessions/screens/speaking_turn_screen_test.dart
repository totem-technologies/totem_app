// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/lib/totem_mobile_api.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/speaking_turn_screen.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
import '../livekit_mocks.dart';

class MockSessionKeeperController extends Mock
    implements SessionKeeperController {}

class _TestSessionCuesService extends SessionCuesService {
  int swipePulseCount = 0;

  @override
  Future<void> pulseSwipeCompletion() async {
    swipePulseCount += 1;
  }

  @override
  Future<void> playSessionTransitionCue() async {}

  @override
  Future<void> playTotemReceivedCue() async {}

  @override
  void dispose() {}
}

/// A minimal [SessionDetailSchema] for testing.
SessionDetailSchema _createTestSession() {
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
    start: DateTime(2024, 6, 1),
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

MockRemoteParticipant _mockRemote(String id, String name) {
  final participant = MockRemoteParticipant(id, name);
  when(participant.createListener).thenReturn(MockParticipantEventsListener());
  when(() => participant.getTrackPublicationBySource(any())).thenReturn(null);
  return participant;
}

List<Participant> _buildParticipantsWithLocal(
  MockLocalParticipant localParticipant,
  int count,
) {
  if (count <= 1) return [localParticipant];

  return [
    localParticipant,
    ...List.generate(
      count - 1,
      (index) => _mockRemote('user-${index + 2}', 'User ${index + 2}'),
    ),
  ];
}

SessionRoomState _buildState({
  RoomStatus status = RoomStatus.active,
  TurnState turnState = TurnState.idle,
  String keeper = 'user-1',
  String currentSpeaker = 'user-1',
  String? nextSpeaker = 'user-2',
  List<Participant>? participants,
}) {
  final defaultParticipants =
      participants ??
      [
        _mockRemote('user-1', 'User One'),
        _mockRemote('user-2', 'User Two'),
        _mockRemote('user-3', 'User Three'),
      ];

  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(participants: defaultParticipants),
    chat: const ChatState(),
    turn: SessionTurnState(
      roomState: RoomState(
        keeper: keeper,
        nextSpeaker: nextSpeaker ?? '',
        currentSpeaker: currentSpeaker,
        status: status,
        turnState: turnState,
        sessionSlug: 'test-session',
        statusDetail: status == RoomStatus.waitingRoom
            ? const RoomStateStatusDetailWaitingRoom(WaitingRoomDetail())
            : const RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

void main() {
  late MockSessionController session;
  late MockSessionKeeperController keeper;
  late MockSessionDeviceController devices;
  late MockLocalParticipant localParticipant;
  late FakeRoom room;

  setUpAll(() {
    setupDotenv();
    registerFallbackValue(TrackSource.camera);
  });

  setUp(() {
    session = MockSessionController();
    keeper = MockSessionKeeperController();
    devices = MockSessionDeviceController();
    localParticipant = MockLocalParticipant('user-1');
    room = FakeRoom(localParticipant);

    when(() => session.room).thenReturn(room);
    when(() => session.keeper).thenReturn(keeper);
    when(() => session.devices).thenReturn(devices);
    when(() => session.isCurrentUserKeeper()).thenReturn(true);
    when(() => devices.isCameraEnabled).thenReturn(false);
    when(() => devices.isMicrophoneEnabled).thenReturn(false);
    when(() => devices.isSpeakerphoneEnabled).thenReturn(false);
    when(() => devices.selectedCameraDeviceId).thenReturn(null);
    when(() => devices.selectedAudioDeviceId).thenReturn(null);
    when(() => devices.selectedAudioOutputDeviceId).thenReturn(null);
    when(() => devices.enableMicrophone()).thenAnswer((_) async {});
    when(() => devices.disableMicrophone()).thenAnswer((_) async {});
    when(() => devices.enableCamera()).thenAnswer((_) async {});
    when(() => devices.disableCamera()).thenAnswer((_) async {});

    when(
      () =>
          localParticipant.getTrackPublicationBySource(TrackSource.microphone),
    ).thenReturn(null);
    when(
      () => localParticipant.getTrackPublicationBySource(TrackSource.camera),
    ).thenReturn(null);
    when(
      () => localParticipant.createListener(),
    ).thenReturn(MockParticipantEventsListener());
  });

  Future<void> pumpSpeakingTurn(
    WidgetTester tester, {
    required SessionRoomState sessionState,
    required bool isKeeper,
    SessionCuesService? cuesService,
  }) async {
    when(() => session.isCurrentUserKeeper()).thenReturn(isKeeper);
    final testCuesService = cuesService ?? _TestSessionCuesService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(
              AuthState.authenticated(
                user: UserSchema(
                  email: 'test@test.com',
                  name: 'Test User',
                  slug: 'user-1',
                  profileAvatarType: ProfileAvatarTypeEnum.td,
                  circleCount: 0,
                  dateCreated: DateTime.now(),
                ),
              ),
            ),
          ),
          currentSessionStateProvider.overrideWithValue(sessionState),
          currentSessionProvider.overrideWith((ref) => session),
          sessionCuesServiceProvider.overrideWithValue(testCuesService),
          userProfileProvider.overrideWith((ref, slug) async {
            return PublicUserSchema(
              slug: slug,
              name: 'User $slug',
              profileAvatarType: ProfileAvatarTypeEnum.td,
              dateCreated: DateTime(2024),
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SpeakingTurnScreen(event: _createTestSession()),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  group('SpeakingTurn', () {
    testWidgets('renders the participant grid for room sizes up to 12', (
      tester,
    ) async {
      for (final participantCount in [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
      ]) {
        final state = _buildState(
          keeper: 'user-1',
          currentSpeaker: 'speaker-0',
          nextSpeaker: 'user-2',
          participants: _buildParticipantsWithLocal(
            localParticipant,
            participantCount,
          ),
        );

        await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

        expect(
          find.byType(ParticipantCard),
          findsNWidgets(participantCount),
        );
        expect(find.byType(SpeakingTurnScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('renders the keeper pass card and session action bar', (
      tester,
    ) async {
      final state = _buildState(
        keeper: 'user-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
      );

      await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ActionSliderButton), findsOneWidget);
      expect(find.text('Your prompt for this round'), findsOneWidget);
      expect(find.text('Pass to User Two'), findsOneWidget);
      expect(find.byType(SessionActionBar), findsOneWidget);
      expect(find.byType(ParticipantCard), findsAtLeastNWidgets(1));
    });

    testWidgets('action bar exposes controls and toggles mic/camera', (
      tester,
    ) async {
      final state = _buildState(
        keeper: 'user-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
      );

      await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

      expect(find.bySemanticsLabel('Microphone off'), findsOneWidget);
      expect(find.bySemanticsLabel('Camera off'), findsOneWidget);
      expect(find.bySemanticsLabel('Chat'), findsOneWidget);
      expect(find.bySemanticsLabel('Send reaction'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Microphone off'));
      await tester.pump();
      verify(() => devices.enableMicrophone()).called(1);

      await tester.tap(find.bySemanticsLabel('Camera off'));
      await tester.pump();
      verify(() => devices.enableCamera()).called(1);
    });

    testWidgets('passes the Totem with a trimmed round message', (
      tester,
    ) async {
      final state = _buildState(
        keeper: 'user-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
      );
      final cuesService = _TestSessionCuesService();

      when(
        () => keeper.passTotem(roundMessage: 'A round message'),
      ).thenAnswer((_) async {});

      await pumpSpeakingTurn(
        tester,
        sessionState: state,
        isKeeper: true,
        cuesService: cuesService,
      );

      await tester.enterText(
        find.byType(TextField),
        '  A round message  ',
      );
      final actionSlider = tester.state(find.byType(ActionSlider)) as dynamic;
      await actionSlider.widget.onActionCompleted();
      await tester.pump();

      verify(
        () => keeper.passTotem(roundMessage: 'A round message'),
      ).called(1);
      expect(cuesService.swipePulseCount, 1);
    });

    testWidgets('shows the standard pass card when the user is not keeper', (
      tester,
    ) async {
      final state = _buildState(
        keeper: 'keeper-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
      );

      await pumpSpeakingTurn(tester, sessionState: state, isKeeper: false);

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ActionSlider), findsOneWidget);
      expect(find.text('Pass to User Two'), findsOneWidget);
      expect(find.byType(SessionActionBar), findsOneWidget);
    });

    testWidgets('shows the waiting receive card while the totem is passing', (
      tester,
    ) async {
      final state = _buildState(
        keeper: 'user-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
        turnState: TurnState.passing,
      );

      await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

      expect(
        find.textContaining('Waiting for the receiver to accept...'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ActionSlider), findsNothing);
      expect(find.byType(SessionActionBar), findsOneWidget);
    });
  });
}
