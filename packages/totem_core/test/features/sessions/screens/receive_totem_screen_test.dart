// ignore_for_file: avoid_dynamic_calls

import 'dart:ui';

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
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';

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
    setupAppConfig();
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
    SessionCuesService? feedbackService,
  }) async {
    final testCuesService = feedbackService ?? _TestSessionCuesService();

    final mouseGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouseGesture.addPointer(location: const Offset(10, 10));
    await tester.pump();
    await mouseGesture.removePointer();
    await tester.pump();

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
          sessionCuesServiceProvider.overrideWithValue(testCuesService),
          userProfileProvider.overrideWith(
            (ref, slug) => Future.value(
              PublicUserSchema(
                slug: slug,
                name: 'Mocked User $slug',
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime.now(),
              ),
            ),
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
      expect(find.byType(ActionSliderButton), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
      expect(find.text('"Take your time"'), findsOneWidget);
    });

    testWidgets('hides round message text when no round message is provided', (
      tester,
    ) async {
      await pumpReceiveTotem(tester, roundMessage: null);

      expect(find.byType(ActionSliderButton), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
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
      final feedbackService = _TestSessionCuesService();

      await pumpReceiveTotem(tester, feedbackService: feedbackService);

      expect(find.byType(ActionSlider), findsOneWidget);
      final actionSlider = tester.state(find.byType(ActionSlider)) as dynamic;
      await actionSlider.widget.onActionCompleted();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => keeper.acceptTotem()).called(1);
      expect(feedbackService.swipePulseCount, 1);
    });

    testWidgets('triggers soft haptic after successful receive swipe', (
      tester,
    ) async {
      final feedbackService = _TestSessionCuesService();

      await pumpReceiveTotem(tester, feedbackService: feedbackService);

      expect(find.byType(ActionSlider), findsOneWidget);
      final actionSlider = tester.state(find.byType(ActionSlider)) as dynamic;
      await actionSlider.widget.onActionCompleted();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(feedbackService.swipePulseCount, 1);
    });

    testWidgets('shows error popup when accept totem fails', (tester) async {
      when(
        () => keeper.acceptTotem(),
      ).thenThrow(Exception('accept failed'));

      final feedbackService = _TestSessionCuesService();

      await pumpReceiveTotem(tester, feedbackService: feedbackService);

      expect(find.byType(ActionSlider), findsOneWidget);
      final actionSlider = tester.state(find.byType(ActionSlider)) as dynamic;
      await actionSlider.widget.onActionCompleted();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => keeper.acceptTotem()).called(1);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('We were unable to accept the totem. Please try again.'),
        findsOneWidget,
      );
      expect(feedbackService.swipePulseCount, 1);
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
      expect(find.byType(ActionSliderButton), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
      expect(find.text('"Breathe and share"'), findsOneWidget);
    });

    testWidgets('renders local participant card when camera is on', (
      tester,
    ) async {
      await pumpReceiveTotem(tester, isCameraOn: true);

      expect(find.byType(ActionSliderButton), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
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

      expect(find.byType(ActionSlider), findsOneWidget);
      final actionSlider = tester.state(find.byType(ActionSlider)) as dynamic;
      await actionSlider.widget.onActionCompleted();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Something went wrong'), findsOneWidget);

      await actionSlider.widget.onActionCompleted();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => keeper.acceptTotem()).called(2);
    });
  });
}
