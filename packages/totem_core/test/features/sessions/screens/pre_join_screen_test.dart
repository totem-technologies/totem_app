import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_screen.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/room_screen.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_mic_button.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/shared/router.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../mocks/flutter_foreground_task_mock.dart';
import '../../../mocks/permission_handler_mock.dart';
import '../../../setup.dart';
import '../livekit_mocks.dart';

const _slug = 'pre-join-screen-test';

class _TrackFactory extends PreJoinPreviewTrackFactory {
  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async => MockLocalVideoTrack();

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    final track = MockLocalAudioTrack();
    when(track.createListener).thenReturn(MockTrackEventsListener());
    return track;
  }
}

class _DelayedTrackFactory extends _TrackFactory {
  final cameraGate = Completer<void>();

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    await cameraGate.future;
    return super.createVideoTrack(cameraOptions);
  }
}

const _options = SessionOptions(
  sessionSlug: _slug,
  token: 'token',
  cameraEnabled: true,
  microphoneEnabled: true,
  speakerEnabled: true,
  cameraOptions: SessionController.defaultCameraCaptureOptions,
);

const _sessionState = SessionRoomState(
  connection: ConnectionState(
    phase: SessionPhase.connected,
    state: RoomConnectionState.connected,
  ),
  participants: ParticipantsState(),
  chat: ChatState(),
  turn: SessionTurnState(
    roomState: RoomState(
      keeper: 'keeper',
      nextSpeaker: '',
      currentSpeaker: '',
      status: RoomStatus.waitingRoom,
      turnState: TurnState.idle,
      sessionSlug: _slug,
      statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
      talkingOrder: <String>[],
      version: 1,
      roundNumber: 1,
    ),
  ),
);

class _PermissionsGrantedFlowController extends PreJoinFlowController {
  @override
  PreJoinFlowState build(String sessionSlug) => const PreJoinFlowState(
    nativePermissionsGranted: true,
  );
}

class _SuccessfulSessionController extends SessionController {
  @override
  SessionRoomState build(SessionOptions options) => _sessionState;

  @override
  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) async =>
      SessionJoinResult.success;
}

class _PendingSessionController extends SessionController {
  static Completer<SessionJoinResult>? joinCompleter;

  @override
  SessionRoomState build(SessionOptions options) => _sessionState;

  @override
  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) =>
      joinCompleter!.future;
}

SessionDetailSchema _event() => SessionDetailSchema(
  slug: _slug,
  title: 'Test Session',
  space: MobileSpaceDetailSchema(
    slug: 'space',
    title: 'Space',
    imageLink: null,
    shortDescription: 'Test',
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
  seatsLeft: 4,
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
);

void main() {
  late VoidCallback restoreWebRtcChannels;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupAppConfig();
    TotemRouter.instance = FakeTotemRouter();
    silenceLogger();
    setupMockFlutterForegroundTask();
    setupMockPermissionHandler();
    restoreWebRtcChannels = stubFlutterWebRtcChannels();
  });

  tearDownAll(() {
    restoreWebRtcChannels();
    clearMockFlutterForegroundTask();
    clearMockPermissionHandler();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Exception? tokenError,
    bool alreadyPresent = false,
    bool successfulJoin = false,
    bool pendingJoin = false,
    bool initiallyOffline = false,
    PreJoinPreviewTrackFactory? trackFactory,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          preJoinPreviewTrackFactoryProvider.overrideWithValue(
            trackFactory ?? _TrackFactory(),
          ),
          isOfflineProvider.overrideWith(
            (ref) => Stream.value(initiallyOffline),
          ),
          sessionTokenProvider(_slug).overrideWith((_) async {
            if (tokenError != null) throw tokenError;
            return JoinResponse(
              token: 'token',
              isAlreadyPresent: alreadyPresent,
            );
          }),
          sessionProvider(_slug).overrideWith((_) async => _event()),
          if (successfulJoin) ...[
            preJoinFlowControllerProvider(
              _slug,
            ).overrideWith(_PermissionsGrantedFlowController.new),
            sessionControllerProvider(
              _options,
            ).overrideWith(_SuccessfulSessionController.new),
          ],
          if (pendingJoin) ...[
            preJoinFlowControllerProvider(
              _slug,
            ).overrideWith(_PermissionsGrantedFlowController.new),
            sessionControllerProvider(
              _options,
            ).overrideWith(_PendingSessionController.new),
          ],
        ],
        child: const SentryDisplayWidget(
          child: MaterialApp(home: PreJoinScreen(sessionSlug: _slug)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('renders declarative pre-join controls', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(ActionBar), findsOneWidget);
    expect(find.byType(ActionSliderButton), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
  });

  testWidgets('locks media toggles during initial capture', (tester) async {
    final factory = _DelayedTrackFactory();
    await pumpScreen(
      tester,
      successfulJoin: true,
      trackFactory: factory,
    );

    expect(
      tester
          .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
          .onToggle,
      isNull,
    );
    expect(
      tester
          .widget<ActionBarCameraSwitcherButton>(
            find.byType(ActionBarCameraSwitcherButton),
          )
          .onToggle,
      isNull,
    );

    factory.cameraGate.complete();
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
          .onToggle,
      isNotNull,
    );
    expect(
      tester
          .widget<ActionBarCameraSwitcherButton>(
            find.byType(ActionBarCameraSwitcherButton),
          )
          .onToggle,
      isNotNull,
    );
  });

  testWidgets('renders token failures through the session error screen', (
    tester,
  ) async {
    await pumpScreen(tester, tokenError: Exception('token failed'));

    expect(find.byType(SessionErrorScreen), findsOneWidget);
    expect(find.text('Try Joining Again'), findsOneWidget);
  });

  testWidgets('renders offline error when internet prevents joining', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      tokenError: Exception('token failed'),
      initiallyOffline: true,
    );

    expect(find.byType(SessionErrorScreen), findsOneWidget);
    expect(find.text("You're Offline"), findsOneWidget);
    expect(
      find.text(
        'Video sessions require an active internet connection.\n'
        'Check your Wi-Fi or mobile data, then tap below to rejoin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('successful join transitions to VideoSessionScreen', (
    tester,
  ) async {
    await pumpScreen(tester, successfulJoin: true);

    final join = tester.widget<ActionSliderButton>(
      find.byType(ActionSliderButton),
    );
    expect(await join.onActionCompleted(), isTrue);
    await tester.pump();

    expect(find.byType(VideoSessionScreen), findsOneWidget);
  });

  testWidgets('transitions while the room connection is still pending', (
    tester,
  ) async {
    _PendingSessionController.joinCompleter = Completer<SessionJoinResult>();
    await pumpScreen(tester, pendingJoin: true);
    final previewRenderer = tester.element(find.byType(VideoTrackRenderer));

    final join = tester.widget<ActionSliderButton>(
      find.byType(ActionSliderButton),
    );
    final joinFuture = join.onActionCompleted();
    await tester.pump();

    expect(find.byType(VideoSessionScreen), findsOneWidget);
    expect(
      tester.element(find.byType(VideoTrackRenderer)),
      same(previewRenderer),
    );

    _PendingSessionController.joinCompleter!.complete(
      SessionJoinResult.success,
    );
    expect(await joinFuture, isTrue);
  });

  testWidgets('shows replacement confirmation only after joining', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      alreadyPresent: true,
      successfulJoin: true,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("You're Already in This Session"), findsNothing);

    final join = tester.widget<ActionSliderButton>(
      find.byType(ActionSliderButton),
    );
    final joinFuture = join.onActionCompleted();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("You're Already in This Session"), findsOneWidget);
    expect(find.text('Join Here'), findsOneWidget);

    await tester.tap(find.text('Join Here'));
    await tester.pump();
    expect(await joinFuture, isTrue);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("You're Already in This Session"), findsNothing);
    expect(find.byType(VideoSessionScreen), findsOneWidget);
  });

  testWidgets('already-present dialog returns true on confirm', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final result = showAlreadyPresentDialog(context);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Here'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
