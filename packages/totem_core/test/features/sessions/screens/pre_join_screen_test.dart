import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
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
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_screen.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_view.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/room_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
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
  final videoTracks = <MockLocalVideoTrack>[];
  final audioTracks = <MockLocalAudioTrack>[];

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    final track = MockLocalVideoTrack();
    videoTracks.add(track);
    return track;
  }

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    final track = MockLocalAudioTrack();
    audioTracks.add(track);
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
    return null;
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
      nextSpeaker: Omittable(''),
      currentSpeaker: Omittable(''),
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
  PreJoinFlowState build(String sessionSlug) =>
      const PreJoinFlowState(nativePermissionsGranted: true);
}

class _WaitingAdmissionFlowController extends PreJoinFlowController {
  @override
  PreJoinFlowState build(String sessionSlug) => const PreJoinFlowState(
    phase: PreJoinFlowPhase.pending,
    admissionStatus: AdmissionStatus.pending,
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

SessionDetailSchema _event({DateTime? start}) => SessionDetailSchema(
  slug: _slug,
  title: 'Test session',
  space: MobileSpaceDetailSchema(
    slug: 'space',
    title: 'Space',
    imageLink: null,
    shortDescription: 'Test',
    content: '',
    author: PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: DateTime(2024),
      slug: const Omittable('keeper'),
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
  start: start ?? DateTime.now().add(const Duration(minutes: 5)),
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

  setUp(() {
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    );
  });

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
    Object? tokenError,
    bool sessionEnded = false,
    bool alreadyPresent = false,
    bool successfulJoin = false,
    bool pendingJoin = false,
    bool initiallyOffline = false,
    bool earlyParticipant = false,
    bool waitingForAdmission = false,
    bool permissionsGranted = false,
    Future<JoinResponse> Function()? getSessionToken,
    Future<SessionDetailSchema> Function()? getSession,
    DateTime Function()? now,
    PreJoinPreviewTrackFactory? trackFactory,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(
              AuthState.authenticated(
                user: UserSchema(
                  profileAvatarType: ProfileAvatarTypeEnum.td,
                  circleCount: 0,
                  email: 'user@example.com',
                  dateCreated: DateTime(2024),
                  name: const Omittable('Test User'),
                  slug: Omittable(earlyParticipant ? 'participant' : 'keeper'),
                ),
              ),
            ),
          ),
          preJoinPreviewTrackFactoryProvider.overrideWithValue(
            trackFactory ?? _TrackFactory(),
          ),
          isOfflineProvider.overrideWith(
            (ref) => Stream.value(initiallyOffline),
          ),
          getRecommendedSessionsProvider(limit: 1).overrideWith((_) => []),
          sessionTokenProvider(_slug).overrideWith((_) {
            if (getSessionToken != null) return getSessionToken();
            // ApiError is the generated client's failure value and deliberately
            // does not implement Exception.
            // ignore: only_throw_errors
            if (tokenError != null) throw tokenError;
            return Future.value(
              JoinResponse(token: 'token', isAlreadyPresent: alreadyPresent),
            );
          }),
          sessionProvider(_slug).overrideWith(
            (_) =>
                getSession?.call() ??
                Future.value(
                  _event(
                    start: earlyParticipant
                        ? DateTime.now().add(const Duration(hours: 1))
                        : null,
                  ).copyWith(ended: sessionEnded),
                ),
          ),
          if (waitingForAdmission)
            preJoinFlowControllerProvider(_slug)
                .overrideWith(_WaitingAdmissionFlowController.new),
          if (permissionsGranted || successfulJoin)
            preJoinFlowControllerProvider(_slug)
                .overrideWith(_PermissionsGrantedFlowController.new),
          if (successfulJoin)
            sessionControllerProvider(_options)
                .overrideWith(_SuccessfulSessionController.new),
          if (pendingJoin) ...[
            preJoinFlowControllerProvider(_slug)
                .overrideWith(_PermissionsGrantedFlowController.new),
            sessionControllerProvider(_options)
                .overrideWith(_PendingSessionController.new),
          ],
        ],
        child: SentryDisplayWidget(
          child: MaterialApp(
            home: PreJoinScreen(sessionSlug: _slug, now: now ?? DateTime.now),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows a disabled pre-join shell while checking eligibility', (
    tester,
  ) async {
    var tokenRequests = 0;
    final session = Completer<SessionDetailSchema>();
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      trackFactory: factory,
      getSessionToken: () {
        tokenRequests++;
        return Future.value(
          const JoinResponse(token: 'token', isAlreadyPresent: false),
        );
      },
      getSession: () => session.future,
    );

    check(tokenRequests).equals(0);
    check(factory.videoTracks).isEmpty();
    check(factory.audioTracks).isEmpty();
    check(tester.widgetList(find.byType(PreJoinView))).length.equals(1);
    check(tester.widgetList(find.byType(CircularProgressIndicator))).isEmpty();
    check(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .enabled,
    ).isFalse();
    check(
      tester
          .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
          .onToggle,
    ).isNull();
    check(
      tester
          .widget<ActionBarCameraSwitcherButton>(
            find.byType(ActionBarCameraSwitcherButton),
          )
          .onToggle,
    ).isNull();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('already-ended sessions do not create preview tracks', (
    tester,
  ) async {
    final factory = _TrackFactory();
    await pumpScreen(tester, sessionEnded: true, trackFactory: factory);

    check(factory.videoTracks).isEmpty();
    check(factory.audioTracks).isEmpty();
    check(tester.widgetList(find.byType(SessionDisconnectedScreen))).length
        .equals(1);
  });

  testWidgets('terminal session errors do not create preview tracks', (
    tester,
  ) async {
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      trackFactory: factory,
      getSession: () async =>
          throw const ApiError<JoinResponse, RoomErrorResponse>(
            statusCode: 409,
            error: RoomErrorResponse(
              code: ErrorCode.notJoinable,
              message: 'Session is not joinable',
            ),
          ),
    );

    check(factory.videoTracks).isEmpty();
    check(factory.audioTracks).isEmpty();
    check(tester.widgetList(find.byType(SessionDisconnectedScreen))).length
        .equals(1);
  });

  testWidgets('terminal session error releases active preview tracks', (
    tester,
  ) async {
    Object? sessionError;
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      trackFactory: factory,
      getSession: () async {
        // ApiError is the generated client's failure value and deliberately
        // does not implement Exception.
        // ignore: only_throw_errors
        if (sessionError != null) throw sessionError;
        return _event();
      },
    );

    check(factory.videoTracks).length.equals(1);
    check(factory.audioTracks).length.equals(1);

    sessionError = const ApiError<JoinResponse, RoomErrorResponse>(
      statusCode: 409,
      error: RoomErrorResponse(
        code: ErrorCode.roomAlreadyEnded,
        message: 'Session already ended',
      ),
    );
    ProviderScope.containerOf(tester.element(find.byType(PreJoinScreen)))
        .invalidate(sessionProvider(_slug));
    await tester.pump();
    await tester.pump();

    check(tester.widgetList(find.byType(SessionDisconnectedScreen))).length
        .equals(1);
    verify(factory.videoTracks.single.stop).called(1);
    verify(factory.videoTracks.single.dispose).called(1);
    verify(factory.audioTracks.single.stop).called(1);
    verify(factory.audioTracks.single.dispose).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('early participant can join when the T-10 window opens', (
    tester,
  ) async {
    var now = DateTime(2030, 1, 1, 12);
    final start = now.add(const Duration(minutes: 11));
    var tokenRequests = 0;
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      earlyParticipant: true,
      permissionsGranted: true,
      now: () => now,
      getSession: () async => _event(start: start).copyWith(started: false),
      trackFactory: factory,
      getSessionToken: () {
        tokenRequests++;
        return Future.value(
          const JoinResponse(token: 'token', isAlreadyPresent: false),
        );
      },
    );

    check(tokenRequests).equals(0);
    check(factory.videoTracks).isEmpty();
    check(factory.audioTracks).isEmpty();
    check(tester.widgetList(find.byType(PreJoinView))).isEmpty();
    check(tester.widgetList(find.textContaining('You can join at'))).length
        .equals(1);
    check(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Join Session'),
          )
          .onPressed,
    ).isNull();

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();

    check(tokenRequests).equals(0);
    check(tester.widgetList(find.textContaining('You can join at'))).isEmpty();
    check(tester.widgetList(find.byType(PreJoinView))).length.equals(1);
    check(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .enabled,
    ).isTrue();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('pending admission shows a waiting room with local preview', (
    tester,
  ) async {
    var tokenRequests = 0;
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      earlyParticipant: true,
      waitingForAdmission: true,
      trackFactory: factory,
      getSessionToken: () {
        tokenRequests++;
        return Future.value(
          const JoinResponse(token: 'token', isAlreadyPresent: false),
        );
      },
    );

    check(tokenRequests).equals(0);
    check(factory.videoTracks).length.equals(1);
    check(factory.audioTracks).length.equals(1);
    check(tester.widgetList(find.byType(PreJoinView))).length.equals(1);
    check(tester.widgetList(find.text('Leave waiting room'))).length.equals(1);
    check(
      tester.widgetList(
        find.textContaining('Waiting for the Keeper to admit you'),
      ),
    ).length.equals(1);
    check(tester.widgetList(find.byType(ActionSliderButton))).isEmpty();
  });

  testWidgets('renders declarative pre-join controls', (tester) async {
    await pumpScreen(tester);

    check(tester.widgetList(find.byType(ActionBar))).length.equals(1);
    check(tester.widgetList(find.byType(ActionSliderButton))).length.equals(1);
    check(tester.widgetList(find.text('Welcome'))).length.equals(1);
  });

  testWidgets(
    'locks media toggles during initial capture',
    (tester) async {
      final factory = _DelayedTrackFactory();
      await pumpScreen(tester, successfulJoin: true, trackFactory: factory);

      check(
        tester
            .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
            .onToggle,
      ).isNull();
      check(
        tester
            .widget<ActionBarCameraSwitcherButton>(
              find.byType(ActionBarCameraSwitcherButton),
            )
            .onToggle,
      ).isNull();

      factory.cameraGate.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      check(
        tester
            .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
            .onToggle,
      ).isNotNull();
      check(
        tester
            .widget<ActionBarCameraSwitcherButton>(
              find.byType(ActionBarCameraSwitcherButton),
            )
            .onToggle,
      ).isNotNull();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets('token failures appear on the pre-join card after Join', (
    tester,
  ) async {
    var tokenRequests = 0;
    await pumpScreen(
      tester,
      getSessionToken: () {
        tokenRequests++;
        throw Exception('token failed');
      },
    );

    check(tokenRequests).equals(0);
    check(tester.widgetList(find.byType(PreJoinView))).length.equals(1);
    final join = tester.widget<ActionSliderButton>(
      find.byType(ActionSliderButton),
    );
    check(await join.onActionCompleted()).isFalse();
    await tester.pump();

    check(tokenRequests).equals(1);
    check(tester.widgetList(find.textContaining('Could not join the Session:')))
        .length
        .equals(1);
    check(tester.widgetList(find.byType(PreJoinView))).length.equals(1);
  });

  testWidgets('renders offline error when internet prevents joining', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      getSession: () async => throw Exception('session failed'),
      initiallyOffline: true,
    );

    check(tester.widgetList(find.byType(SessionErrorScreen))).length.equals(1);
    check(tester.widgetList(find.text("You're Offline"))).length.equals(1);
    check(
      tester.widgetList(
        find.text(
          'Video sessions require an active internet connection.\n'
          'Check your Wi-Fi or mobile data, then tap below to rejoin.',
        ),
      ),
    ).length.equals(1);
  });

  testWidgets('successful join transitions to VideoSessionScreen', (
    tester,
  ) async {
    await pumpScreen(tester, successfulJoin: true);

    final join = tester.widget<ActionSliderButton>(
      find.byType(ActionSliderButton),
    );
    check(await join.onActionCompleted()).equals(true);
    await tester.pump();

    check(tester.widgetList(find.byType(VideoSessionScreen))).length.equals(1);
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

    check(tester.widgetList(find.byType(VideoSessionScreen))).length.equals(1);
    check(tester.element(find.byType(VideoTrackRenderer)))
        .identicalTo(previewRenderer);

    _PendingSessionController.joinCompleter!.complete(
      SessionJoinResult.success,
    );
    check(await joinFuture).equals(true);
  });

  testWidgets('shows replacement confirmation only after joining', (
    tester,
  ) async {
    await pumpScreen(tester, alreadyPresent: true, successfulJoin: true);
    await tester.pump(const Duration(milliseconds: 300));

    check(tester.widgetList(find.text("You're already in this session"))).length
        .equals(0);

    final join = tester.widget<ActionSliderButton>(
      find.byType(ActionSliderButton),
    );
    final joinFuture = join.onActionCompleted();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    check(tester.widgetList(find.text("You're already in this session"))).length
        .equals(1);
    check(tester.widgetList(find.text('Join Here'))).length.equals(1);

    await tester.tap(find.text('Join Here'));
    await tester.pump();
    check(await joinFuture).equals(true);
    await tester.pump(const Duration(milliseconds: 300));

    check(tester.widgetList(find.text("You're already in this session"))).length
        .equals(0);
    check(tester.widgetList(find.byType(VideoSessionScreen))).length.equals(1);
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
    check(await result).equals(true);
  });
}
