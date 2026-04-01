import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
import '../livekit_mocks.dart';

class MockSessionKeeperController extends Mock
    implements SessionKeeperController {}

SessionRoomState _buildState({
  RoomStatus status = RoomStatus.active,
  TurnState turnState = TurnState.passing,
}) {
  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(
      participants: [
        MockLocalParticipant('user-1'),
        MockRemoteParticipant('user-2', 'User Two'),
      ],
    ),
    chat: const ChatState(),
    turn: SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: 'user-1',
        currentSpeaker: 'user-2',
        status: status,
        turnState: turnState,
        sessionSlug: 'test-session',
        statusDetail: const RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

void main() {
  late MockSessionController session;
  late MockSessionDeviceController devices;
  late MockSessionKeeperController keeper;
  late MockLocalParticipant localParticipant;
  late FakeRoom room;

  setUpAll(() {
    setupDotenv();
    registerFallbackValue(TrackSource.camera);
  });

  setUp(() {
    session = MockSessionController();
    devices = MockSessionDeviceController();
    keeper = MockSessionKeeperController();
    localParticipant = MockLocalParticipant('user-1');
    room = FakeRoom(localParticipant);

    when(() => session.room).thenReturn(room);
    when(() => session.devices).thenReturn(devices);
    when(() => session.keeper).thenReturn(keeper);
    when(() => session.isCurrentUserKeeper()).thenReturn(false);

    when(() => devices.enableMicrophone()).thenAnswer((_) async {});
    when(() => devices.disableMicrophone()).thenAnswer((_) async {});
    when(() => devices.enableCamera()).thenAnswer((_) async {});
    when(() => devices.disableCamera()).thenAnswer((_) async {});
    when(() => keeper.acceptTotem()).thenAnswer((_) async {});

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

  Future<void> pumpReceiveTotem(
    WidgetTester tester, {
    SessionRoomState? state,
    String? roundMessage,
    bool isCameraOn = false,
  }) async {
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
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionStateProvider.overrideWithValue(state ?? _buildState()),
          roomStatusProvider.overrideWith((ref) => RoomStatus.active),
          roundMessageProvider.overrideWith((ref) => roundMessage),
          isCameraOnProvider.overrideWith((ref) => isCameraOn),
          resolveCurrentScreenProvider.overrideWith(
            (ref) => RoomScreen.receiving,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ReceiveTotemScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ReceiveTotemScreen action bar', () {
    testWidgets('shows receiving controls without emoji action', (
      tester,
    ) async {
      await pumpReceiveTotem(tester, roundMessage: 'Take your time');

      expect(find.byType(SessionActionBar), findsOneWidget);
      expect(find.bySemanticsLabel('Microphone off'), findsOneWidget);
      expect(find.bySemanticsLabel('Camera off'), findsOneWidget);
      expect(find.bySemanticsLabel('Chat'), findsOneWidget);
      expect(find.bySemanticsLabel('Send reaction'), findsNothing);
      expect(find.text('Slide to Receive'), findsOneWidget);
      expect(find.text('"Take your time"'), findsOneWidget);
    });

    testWidgets('hides round message text when no round message is provided', (
      tester,
    ) async {
      await pumpReceiveTotem(tester, roundMessage: null);

      expect(find.text('Slide to Receive'), findsOneWidget);
      expect(find.text('"Take your time"'), findsNothing);
    });

    testWidgets('toggles mic and camera from action bar', (tester) async {
      await pumpReceiveTotem(tester);

      await tester.tap(find.bySemanticsLabel('Microphone off'));
      await tester.pump();
      verify(() => devices.enableMicrophone()).called(1);

      await tester.tap(find.bySemanticsLabel('Camera off'));
      await tester.pump();
      verify(() => devices.enableCamera()).called(1);
    });

    testWidgets('accepts totem when slider completes', (tester) async {
      await pumpReceiveTotem(tester);

      await tester.drag(find.byType(ActionSlider), const Offset(500, 0));
      await tester.pump();

      verify(() => keeper.acceptTotem()).called(1);
    });

    testWidgets('shows error popup when accept totem fails', (tester) async {
      when(
        () => keeper.acceptTotem(),
      ).thenThrow(Exception('accept failed'));

      await pumpReceiveTotem(tester);

      await tester.drag(find.byType(ActionSlider), const Offset(500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => keeper.acceptTotem()).called(1);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('We were unable to accept the totem. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('renders correctly in landscape orientation', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpReceiveTotem(tester, roundMessage: 'Breathe and share');

      expect(find.byType(SessionActionBar), findsOneWidget);
      expect(find.text('Slide to Receive'), findsOneWidget);
      expect(find.text('"Breathe and share"'), findsOneWidget);
    });

    testWidgets('renders local participant card when camera is on', (
      tester,
    ) async {
      await pumpReceiveTotem(tester, isCameraOn: true);

      expect(find.text('Slide to Receive'), findsOneWidget);
      expect(find.byType(SessionActionBar), findsOneWidget);
    });

    testWidgets('allows retry after a failed receive attempt', (tester) async {
      var callCount = 0;
      when(() => keeper.acceptTotem()).thenAnswer((_) async {
        callCount += 1;
        if (callCount == 1) {
          throw Exception('accept failed once');
        }
      });

      await pumpReceiveTotem(tester);

      await tester.drag(find.byType(ActionSlider), const Offset(500, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.drag(find.byType(ActionSlider), const Offset(500, 0));
      await tester.pump();

      verify(() => keeper.acceptTotem()).called(2);
    });
  });
}
