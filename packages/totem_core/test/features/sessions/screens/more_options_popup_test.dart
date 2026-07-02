import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/more_options_popup.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
import '../livekit_mocks.dart';

class MockSessionKeeperController extends Mock
    implements SessionKeeperController {}

class _TestSessionDeviceController extends SessionDeviceController {
  static const _defaultState = SessionDeviceState(
    selectedCameraDeviceId: null,
    selectedAudioDeviceId: null,
    selectedAudioOutputDeviceId: null,
    isSpeakerphoneEnabled: false,
    isMicrophoneEnabled: false,
    isCameraEnabled: false,
  );

  @override
  SessionDeviceState build(SessionController session) => _defaultState;
}

SessionRoomState _sessionState({
  required RoomState roomState,
  List<Participant> participants = const [],
}) {
  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(participants: participants),
    chat: const ChatState(),
    turn: SessionTurnState(roomState: roomState),
  );
}

Future<void> _pumpMoreOptions(
  WidgetTester tester, {
  required MockSessionController session,
  required SessionRoomState state,
  required _TestSessionDeviceController deviceController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.unauthenticated()),
        ),
        currentSessionProvider.overrideWith((ref) => session),
        currentSessionStateProvider.overrideWithValue(state),
        sessionDeviceControllerProvider(
          session,
        ).overrideWith(() => deviceController),
        isCameraOnProvider.overrideWith((ref) => false),
        userProfileProvider.overrideWith(
          (ref, slug) => Future.value(
            PublicUserSchema(
              slug: slug,
              name: 'User $slug',
              profileAvatarType: ProfileAvatarTypeEnum.td,
              circleCount: 0,
              dateCreated: DateTime(2024),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MoreOptions(
            session: SessionDetailSchema(
              slug: 'test-session',
              title: 'Test Session',
              space: MobileSpaceDetailSchema(
                slug: 'test-space',
                title: 'Test Space',
                imageLink: null,
                shortDescription: '',
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
              start: DateTime(2024),
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
            ),
            isDialog: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late MockSessionController session;
  late MockSessionDeviceController devices;
  late MockSessionKeeperController keeper;
  late _TestSessionDeviceController deviceController;

  setUpAll(() {
    setupAppConfig();
    registerFallbackValue(TrackSource.camera);
  });

  setUp(() {
    session = MockSessionController();
    devices = MockSessionDeviceController();
    keeper = MockSessionKeeperController();
    deviceController = _TestSessionDeviceController();

    when(() => session.devices).thenReturn(devices);
    when(() => session.keeper).thenReturn(keeper);
    when(() => session.isCurrentUserKeeper()).thenReturn(true);
    when(() => devices.isSpeakerphoneEnabled).thenReturn(false);
    when(() => devices.selectedAudioOutputDeviceId).thenReturn(null);
    when(() => devices.localVideoTrack).thenReturn(null);
    when(() => devices.switchCameraPosition()).thenAnswer((_) async {});
    when(() => keeper.forcePassTotem()).thenAnswer((_) async {});
  });

  group('_onForcePass', () {
    // ── Preconditions ──────────────────────────────────────────────

    testWidgets('force pass tile is present but not tappable when idle', (
      tester,
    ) async {
      final state = _sessionState(
        roomState: const RoomState(
          keeper: 'keeper-1',
          nextSpeaker: 'user-2',
          currentSpeaker: 'user-1',
          status: RoomStatus.active,
          turnState: TurnState.idle,
          sessionSlug: 'test-session',
          statusDetail: RoomStateStatusDetailActive(
            ActiveDetail(),
          ),
          talkingOrder: ['user-1', 'user-2'],
          version: 1,
          roundNumber: 1,
        ),
      );

      await _pumpMoreOptions(
        tester,
        session: session,
        state: state,
        deviceController: deviceController,
      );

      // Tile is rendered but with null onTap
      expect(find.textContaining('Force pass'), findsOneWidget);

      // Tapping does nothing — no dialog appears
      await tester.tap(find.textContaining('Force pass'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    testWidgets('force pass tile is not shown when not keeper', (
      tester,
    ) async {
      when(() => session.isCurrentUserKeeper()).thenReturn(false);

      final state = _sessionState(
        roomState: const RoomState(
          keeper: 'keeper-1',
          nextSpeaker: 'user-2',
          currentSpeaker: 'user-1',
          status: RoomStatus.active,
          turnState: TurnState.speaking,
          sessionSlug: 'test-session',
          statusDetail: RoomStateStatusDetailActive(
            ActiveDetail(),
          ),
          talkingOrder: ['user-1', 'user-2'],
          version: 1,
          roundNumber: 1,
        ),
      );

      await _pumpMoreOptions(
        tester,
        session: session,
        state: state,
        deviceController: deviceController,
      );

      expect(find.textContaining('Force pass'), findsNothing);
    });

    testWidgets('force pass tile is not shown when not active', (
      tester,
    ) async {
      final state = _sessionState(
        roomState: const RoomState(
          keeper: 'keeper-1',
          nextSpeaker: 'user-2',
          currentSpeaker: 'user-1',
          status: RoomStatus.waitingRoom,
          turnState: TurnState.speaking,
          sessionSlug: 'test-session',
          statusDetail: RoomStateStatusDetailWaitingRoom(
            WaitingRoomDetail(),
          ),
          talkingOrder: ['user-1', 'user-2'],
          version: 1,
          roundNumber: 1,
        ),
      );

      await _pumpMoreOptions(
        tester,
        session: session,
        state: state,
        deviceController: deviceController,
      );

      expect(find.textContaining('Force pass'), findsNothing);
    });

    // ── Dialog content: normal speaking turn ───────────────────────

    testWidgets(
      'shows confirmation dialog with next participant name from list',
      (tester) async {
        final p1 = MockLocalParticipant('user-1', 'p1');
        final p2 = MockLocalParticipant('user-2', 'p2');

        final state = _sessionState(
          roomState: const RoomState(
            keeper: 'keeper-1',
            nextSpeaker: 'user-2',
            currentSpeaker: 'user-1',
            status: RoomStatus.active,
            turnState: TurnState.speaking,
            sessionSlug: 'test-session',
            statusDetail: RoomStateStatusDetailActive(
              ActiveDetail(),
            ),
            talkingOrder: ['user-1', 'user-2', 'user-3'],
            version: 1,
            roundNumber: 1,
          ),
          participants: [p1, p2],
        );

        await _pumpMoreOptions(
          tester,
          session: session,
          state: state,
          deviceController: deviceController,
        );

        await tester.tap(find.textContaining('Force pass'));
        await tester.pumpAndSettle();

        // p2 is in participants list — uses MockLocalParticipant name
        expect(find.textContaining(p2.name), findsOneWidget);
        expect(
          find.textContaining("the current speaker's turn"),
          findsOneWidget,
        );
        expect(find.text('Are you sure?'), findsOneWidget);
      },
    );

    // ── Confirm action: success ────────────────────────────────────

    testWidgets('confirm calls forcePassTotem and closes dialog', (
      tester,
    ) async {
      final state = _sessionState(
        roomState: const RoomState(
          keeper: 'keeper-1',
          nextSpeaker: 'user-2',
          currentSpeaker: 'user-1',
          status: RoomStatus.active,
          turnState: TurnState.speaking,
          sessionSlug: 'test-session',
          statusDetail: RoomStateStatusDetailActive(
            ActiveDetail(),
          ),
          talkingOrder: ['user-1', 'user-2'],
          version: 1,
          roundNumber: 1,
        ),
        participants: [
          MockLocalParticipant('user-1'),
          MockLocalParticipant('user-2'),
        ],
      );

      await _pumpMoreOptions(
        tester,
        session: session,
        state: state,
        deviceController: deviceController,
      );

      await tester.tap(find.textContaining('Force pass'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Force pass'));
      await tester.pumpAndSettle();

      verify(() => keeper.forcePassTotem()).called(1);
      // Dialog should be closed
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    // ── Early return ───────────────────────────────────────────────

    testWidgets('returns early when nextParticipantIdentity is null', (
      tester,
    ) async {
      // empty talkingOrder → nextParticipantIdentity returns null
      final state = _sessionState(
        roomState: const RoomState(
          keeper: 'keeper-1',
          nextSpeaker: null,
          currentSpeaker: null,
          status: RoomStatus.active,
          turnState: TurnState.speaking,
          sessionSlug: 'test-session',
          statusDetail: RoomStateStatusDetailActive(
            ActiveDetail(),
          ),
          talkingOrder: [],
          version: 1,
          roundNumber: 1,
        ),
      );

      await _pumpMoreOptions(
        tester,
        session: session,
        state: state,
        deviceController: deviceController,
      );

      // The tile is still shown (turnState != idle) so tap it
      await tester.tap(find.textContaining('Force pass'));
      await tester.pumpAndSettle();

      // No dialog should appear because nextParticipantIdentity is null
      expect(find.byType(ConfirmationDialog), findsNothing);
      verifyNever(() => keeper.forcePassTotem());
    });
  });
}
