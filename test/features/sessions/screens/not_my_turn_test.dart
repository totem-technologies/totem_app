// ignore_for_file: comment_references

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
import 'package:totem_app/features/sessions/screens/not_my_turn.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/grounding_marquee.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
import '../livekit_mocks.dart';

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

/// Creates a [MockRemoteParticipant] with [createListener] stubbed.
MockRemoteParticipant _mockRemote(String id, String name) {
  final p = MockRemoteParticipant(id, name);
  when(p.createListener).thenReturn(MockParticipantEventsListener());
  when(() => p.getTrackPublicationBySource(any())).thenReturn(null);
  return p;
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
  String keeper = 'keeper-1',
  String currentSpeaker = 'speaker-1',
  String? nextSpeaker = 'user-2',
  List<String> talkingOrder = const [],
  List<Participant>? participants,
  bool hasKeeperDisconnected = false,
}) {
  final defaultParticipants =
      participants ??
      [
        _mockRemote('user-1', 'User One'),
        _mockRemote('user-2', 'User Two'),
        _mockRemote('speaker-1', 'Speaker One'),
        _mockRemote('keeper-1', 'The Keeper'),
      ];

  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(
      participants: defaultParticipants,
      hasKeeperDisconnected: hasKeeperDisconnected,
    ),
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
        talkingOrder: talkingOrder,
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

List<String> _participantGridIdentities(WidgetTester tester) {
  return tester
      .widgetList<ParticipantCard>(find.byType(ParticipantCard))
      .map((card) => card.participantIdentity)
      .toList();
}

class _TestLastMessageNotifier extends Notifier<SessionChatMessage?> {
  @override
  SessionChatMessage? build() => null;
}

final _testLastMessageProvider =
    NotifierProvider<_TestLastMessageNotifier, SessionChatMessage?>(
      _TestLastMessageNotifier.new,
    );

void main() {
  late MockSessionController session;
  late MockSessionDeviceController devices;
  late MockLocalParticipant localParticipant;
  late FakeRoom room;

  setUpAll(() {
    registerFallbackValue(TrackSource.camera);
  });

  setUp(() {
    session = MockSessionController();
    devices = MockSessionDeviceController();
    localParticipant = MockLocalParticipant('user-1');
    room = FakeRoom(localParticipant);

    when(() => session.room).thenReturn(room);
    when(() => session.devices).thenReturn(devices);
    when(() => session.isCurrentUserKeeper()).thenReturn(false);
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

  Future<void> pumpNotMyTurn(
    WidgetTester tester, {
    required SessionRoomState sessionState,
    String currentUserSlug = 'user-1',
    bool isKeeper = false,
  }) async {
    when(() => session.isCurrentUserKeeper()).thenReturn(isKeeper);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(
              AuthState.authenticated(
                user: UserSchema(
                  email: 'test@test.com',
                  name: 'Test User',
                  slug: currentUserSlug,
                  profileAvatarType: ProfileAvatarTypeEnum.td,
                  circleCount: 0,
                  dateCreated: DateTime.now(),
                ),
              ),
            ),
          ),
          currentSessionStateProvider.overrideWithValue(sessionState),
          currentSessionProvider.overrideWith((ref) => session),
          isCurrentUserKeeperProvider.overrideWith((ref) => isKeeper),
          amNextSpeakerProvider.overrideWith((ref) {
            final state = ref.watch(currentSessionStateProvider);
            if (state == null) return false;
            return state.roomState.nextSpeaker == currentUserSlug;
          }),
          roomStatusProvider.overrideWith((ref) {
            final state = ref.watch(currentSessionStateProvider);
            return state?.roomState.status ?? RoomStatus.waitingRoom;
          }),
          hasKeeperProvider.overrideWith((ref) {
            final state = ref.watch(currentSessionStateProvider);
            return state?.hasKeeper ?? false;
          }),
          featuredParticipantProvider.overrideWith((ref) {
            final state = ref.watch(currentSessionStateProvider);
            return state?.featuredParticipant();
          }),
          speakingNextParticipantProvider.overrideWith((ref) {
            final state = ref.watch(currentSessionStateProvider);
            return state?.speakingNextParticipant();
          }),
          resolveCurrentScreenProvider.overrideWith(
            (ref) => RoomScreen.notMyTurn,
          ),
          lastSessionMessageProvider.overrideWith(
            (ref) => ref.watch(_testLastMessageProvider),
          ),
          sessionMessagesProvider.overrideWith((ref) => const []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NotMyTurn(event: _createTestSession()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('NotMyTurn', () {
    group('participant grid', () {
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
            status: RoomStatus.active,
            keeper: 'keeper-0',
            currentSpeaker: 'speaker-0',
            nextSpeaker: 'user-1',
            participants: _buildParticipantsWithLocal(
              localParticipant,
              participantCount,
            ),
          );

          await pumpNotMyTurn(tester, sessionState: state);

          expect(
            find.byType(ParticipantCard),
            findsNWidgets(participantCount),
          );
          expect(find.byType(NotMyTurn), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });

      testWidgets('updates participant order when talking order changes', (
        tester,
      ) async {
        final participants = [
          _mockRemote('user-1', 'User One'),
          _mockRemote('user-2', 'User Two'),
          _mockRemote('user-3', 'User Three'),
          _mockRemote('keeper-1', 'Keeper'),
        ];

        final initialState = _buildState(
          status: RoomStatus.active,
          keeper: 'keeper-1',
          currentSpeaker: 'keeper-1',
          nextSpeaker: 'user-2',
          talkingOrder: const ['keeper-1', 'user-2', 'user-3', 'user-1'],
          participants: participants,
        );

        await pumpNotMyTurn(tester, sessionState: initialState);
        expect(
          _participantGridIdentities(tester),
          equals(const ['user-2', 'user-3', 'user-1']),
        );

        final reorderedState = _buildState(
          status: RoomStatus.active,
          keeper: 'keeper-1',
          currentSpeaker: 'keeper-1',
          nextSpeaker: 'user-3',
          talkingOrder: const ['keeper-1', 'user-3', 'user-1', 'user-2'],
          participants: participants,
        );

        await pumpNotMyTurn(tester, sessionState: reorderedState);
        expect(
          _participantGridIdentities(tester),
          equals(const ['user-3', 'user-1', 'user-2']),
        );
      });
    });

    group('waitingRoom status without keeper', () {
      testWidgets('shows "Waiting for the Keeper to join..." text', (
        tester,
      ) async {
        final state = _buildState(
          status: RoomStatus.waitingRoom,
          keeper: 'keeper-1',
          participants: [
            _mockRemote('user-1', 'User One'),
            _mockRemote('user-2', 'User Two'),
          ],
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(
          find.text('Waiting for the Keeper to join...'),
          findsOneWidget,
        );
      });

      testWidgets('shows GroundingMarquee for non-keeper', (tester) async {
        final state = _buildState(
          status: RoomStatus.waitingRoom,
          participants: [
            _mockRemote('user-1', 'User One'),
            _mockRemote('user-2', 'User Two'),
          ],
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(find.byType(GroundingMarquee), findsOneWidget);
      });
    });

    group('waitingRoom status with keeper', () {
      testWidgets('shows "The session is about to start..." text', (
        tester,
      ) async {
        final state = _buildState(
          status: RoomStatus.waitingRoom,
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(
          find.text('The session is about to start...'),
          findsOneWidget,
        );
      });

      testWidgets(
        'non-keeper sees GroundingMarquee instead of start button',
        (tester) async {
          final state = _buildState(
            status: RoomStatus.waitingRoom,
          );

          await pumpNotMyTurn(
            tester,
            sessionState: state,
            isKeeper: false,
          );

          // Non-keeper should see the marquee, not the start button.
          expect(find.byType(GroundingMarquee), findsOneWidget);
        },
      );
    });

    group('active status', () {
      Finder findRichTextContaining(String text) {
        return find.byWidgetPredicate((widget) {
          if (widget is! RichText) return false;
          return widget.text.toPlainText().contains(text);
        });
      }

      testWidgets(
        'shows "You are Next" when current user is the next speaker',
        (tester) async {
          final state = _buildState(
            status: RoomStatus.active,
            nextSpeaker: 'user-1',
          );

          await pumpNotMyTurn(
            tester,
            sessionState: state,
            currentUserSlug: 'user-1',
          );

          expect(findRichTextContaining('You are Next'), findsOneWidget);
        },
      );

      testWidgets('shows "Next up {name}" when another user is next', (
        tester,
      ) async {
        final state = _buildState(
          status: RoomStatus.active,
          nextSpeaker: 'user-2',
        );

        await pumpNotMyTurn(
          tester,
          sessionState: state,
          currentUserSlug: 'user-1',
        );

        expect(findRichTextContaining('Next up User Two'), findsOneWidget);
      });

      testWidgets('does NOT show marquee or transition card', (tester) async {
        final state = _buildState(
          status: RoomStatus.active,
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(find.byType(GroundingMarquee), findsNothing);
      });
    });

    group('active status without keeper (paused)', () {
      testWidgets('shows "The session has been paused..." text', (
        tester,
      ) async {
        final state = _buildState(
          status: RoomStatus.active,
          keeper: 'keeper-1',
          participants: [
            _mockRemote('user-1', 'User One'),
            _mockRemote('user-2', 'User Two'),
          ],
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(
          find.text('The session has been paused...'),
          findsOneWidget,
        );
      });
    });

    group('session action bar', () {
      testWidgets('renders SessionActionBar', (tester) async {
        final state = _buildState(
          status: RoomStatus.active,
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(find.byType(SessionActionBar), findsOneWidget);
      });

      testWidgets('shows reaction control and toggles mic/camera', (
        tester,
      ) async {
        final state = _buildState(
          status: RoomStatus.active,
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(find.bySemanticsLabel('Microphone off'), findsOneWidget);
        expect(find.bySemanticsLabel('Camera off'), findsOneWidget);
        expect(find.bySemanticsLabel('Chat'), findsOneWidget);
        expect(find.bySemanticsLabel('Send reaction'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Microphone off'));
        await tester.pump();
        verify(() => devices.enableMicrophone()).called(1);

        await tester.tap(find.bySemanticsLabel('Camera off'));
        await tester.pump();
        verify(() => devices.enableCamera()).called(1);
      });
    });

    group('widget structure', () {
      testWidgets('renders NotMyTurn without crashing', (tester) async {
        final state = _buildState(
          status: RoomStatus.active,
        );

        await pumpNotMyTurn(tester, sessionState: state);

        expect(find.byType(NotMyTurn), findsOneWidget);
      });
    });
  });
}
