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
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/ui/priming_sheet.dart';
import 'package:totem_core/features/permissions/ui/recovery.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_preview_card.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_screen.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_view.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/room_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_mic_button.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/session_declined_view.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_view.dart';
import 'package:totem_core/shared/router.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../mocks/flutter_foreground_task_mock.dart';
import '../../../setup.dart';
import '../../permissions/fake_media_permission_adapter.dart';
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

class _WaitingAdmissionFlowController extends PreJoinFlowController {
  @override
  PreJoinFlowState build(String sessionSlug) => const PreJoinFlowState(
    phase: PreJoinFlowPhase.pending,
    admissionStatus: AdmissionStatus.pending,
  );
}

class _MutableFlowController extends PreJoinFlowController {
  @override
  PreJoinFlowState build(String sessionSlug) => const PreJoinFlowState();

  void setPhase(PreJoinFlowPhase phase, {AdmissionStatus? admissionStatus}) {
    state = PreJoinFlowState(
      phase: phase,
      admissionStatus: admissionStatus,
    );
  }
}

class _TerminalAdmissionFlowController extends PreJoinFlowController {
  _TerminalAdmissionFlowController(this.status);

  final AdmissionStatus status;

  @override
  PreJoinFlowState build(String sessionSlug) =>
      PreJoinFlowState(admissionStatus: status);
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
      name: const Omittable('Morgan Keeper'),
    ),
    category: null,
    subscribers: 0,
    recurring: null,
    price: 0,
    nextEvents: const [],
  ),
  content: 'A quiet space to connect and reflect.',
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
    restoreWebRtcChannels = stubFlutterWebRtcChannels();
  });

  tearDownAll(() {
    restoreWebRtcChannels();
    clearMockFlutterForegroundTask();
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
    AdmissionStatus? terminalAdmissionStatus,

    Future<JoinResponse> Function()? getSessionToken,
    Future<SessionDetailSchema> Function()? getSession,
    DateTime Function()? now,
    PreJoinPreviewTrackFactory? trackFactory,
    PreJoinFlowController Function()? flowController,
    FakeMediaPermissionAdapter? adapter,
    PlatformInfo platform = const IosApp(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformInfoProvider.overrideWithValue(platform),
          mediaPermissionAdapterProvider.overrideWithValue(
            adapter ?? FakeMediaPermissionAdapter(),
          ),
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
            preJoinFlowControllerProvider(
              _slug,
            ).overrideWith(_WaitingAdmissionFlowController.new),
          if (terminalAdmissionStatus != null)
            preJoinFlowControllerProvider(_slug).overrideWith(
              () => _TerminalAdmissionFlowController(terminalAdmissionStatus),
            ),
          if (flowController != null)
            preJoinFlowControllerProvider(_slug).overrideWith(flowController),

          if (successfulJoin)
            sessionControllerProvider(
              _options,
            ).overrideWith(_SuccessfulSessionController.new),
          if (pendingJoin) ...[
            sessionControllerProvider(
              _options,
            ).overrideWith(_PendingSessionController.new),
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
    check(
      tester.widgetList(find.byType(SessionDisconnectedScreen)),
    ).length.equals(1);
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
    check(
      tester.widgetList(find.byType(SessionDisconnectedScreen)),
    ).length.equals(1);
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
    ProviderScope.containerOf(
      tester.element(find.byType(PreJoinScreen)),
    ).invalidate(sessionProvider(_slug));
    await tester.pump();
    await tester.pump();

    check(
      tester.widgetList(find.byType(SessionDisconnectedScreen)),
    ).length.equals(1);
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
    check(factory.videoTracks).length.equals(1);
    check(factory.audioTracks).length.equals(1);
    check(find.byType(PreJoinView).evaluate()).isNotEmpty();
    check(find.text('Join opens at 12:01 PM.').evaluate()).isNotEmpty();
    check(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .enabled,
    ).isFalse();

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();

    check(tokenRequests).equals(0);
    check(find.text('Join opens at 12:01 PM.').evaluate()).isEmpty();
    check(find.byType(PreJoinView).evaluate()).isNotEmpty();
    check(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .enabled,
    ).isTrue();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Keeper can join directly before the participant window', (
    tester,
  ) async {
    final now = DateTime(2030, 1, 1, 12);
    var tokenRequests = 0;
    await pumpScreen(
      tester,
      successfulJoin: true,
      now: () => now,
      getSession: () async => _event(start: now.add(const Duration(hours: 1))),
      getSessionToken: () async {
        tokenRequests++;
        return const JoinResponse(token: 'token', isAlreadyPresent: false);
      },
    );

    check(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .enabled,
    ).isTrue();
    check(find.byType(SessionWaitingView).evaluate()).isEmpty();
    check(tokenRequests).equals(0);
    unawaited(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .onActionCompleted(),
    );
    await tester.pump();
    await tester.pump();

    check(tokenRequests).equals(1);
    check(find.byType(VideoSessionScreen).evaluate()).isNotEmpty();
    check(find.byType(SessionWaitingView).evaluate()).isEmpty();
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
    check(find.byType(SessionWaitingView).evaluate()).isNotEmpty();
    check(find.byType(SessionWaitingCard).evaluate()).isNotEmpty();
    check(
      find.bySemanticsLabel(RegExp('Your video preview, camera on')).evaluate(),
    ).isNotEmpty();
    check(find.byType(VideoSessionScreen).evaluate()).isEmpty();
    check(tester.widgetList(find.text('Leave waiting room'))).length.equals(1);
    check(
      tester.widgetList(find.textContaining('The Keeper will let you in.')),
    ).length.equals(1);
    check(tester.widgetList(find.byType(ActionSliderButton))).isEmpty();
  });

  testWidgets(
    'keeps the preview and media controls mounted across joining states',
    (tester) async {
      final factory = _TrackFactory();
      await pumpScreen(
        tester,
        trackFactory: factory,
        flowController: _MutableFlowController.new,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PreJoinScreen)),
      );
      final flow =
          (container.read(
                  preJoinFlowControllerProvider(_slug).notifier,
                )
                as _MutableFlowController)
            ..setPhase(PreJoinFlowPhase.joining);
      await tester.pump();
      final preview = tester.element(find.byType(LocalParticipantCard));
      final controls = tester.element(find.byType(SessionKeyboardShortcuts));
      check(factory.videoTracks).length.equals(1);
      check(factory.audioTracks).length.equals(1);

      flow.setPhase(
        PreJoinFlowPhase.pending,
        admissionStatus: AdmissionStatus.pending,
      );
      await tester.pump();
      check(tester.element(find.byType(LocalParticipantCard))).identicalTo(
        preview,
      );
      check(tester.element(find.byType(SessionKeyboardShortcuts))).identicalTo(
        controls,
      );

      flow.setPhase(
        PreJoinFlowPhase.joining,
        admissionStatus: AdmissionStatus.approved,
      );
      await tester.pump();
      check(tester.element(find.byType(LocalParticipantCard))).identicalTo(
        preview,
      );
      check(tester.element(find.byType(SessionKeyboardShortcuts))).identicalTo(
        controls,
      );
      check(factory.videoTracks).length.equals(1);
      check(factory.audioTracks).length.equals(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final status in [AdmissionStatus.denied, AdmissionStatus.expired]) {
    testWidgets('$status shows a declined screen instead of a join action', (
      tester,
    ) async {
      final factory = _TrackFactory();
      await pumpScreen(
        tester,
        terminalAdmissionStatus: status,
        trackFactory: factory,
      );

      check(find.byType(SessionDeclinedView).evaluate()).isNotEmpty();
      check(
        find
            .text(
              status == AdmissionStatus.denied
                  ? 'The Keeper was unable to admit you.'
                  : 'Your admission request has expired.',
            )
            .evaluate(),
      ).isNotEmpty();
      check(find.text('Return to the Space').evaluate()).isNotEmpty();
      check(find.text('Join session').evaluate()).isEmpty();
      check(find.byType(VideoSessionScreen).evaluate()).isEmpty();
      check(factory.videoTracks).isEmpty();
    });
  }

  for (final size in [
    const Size(360, 800),
    const Size(900, 800),
    const Size(1280, 720),
    const Size(1024, 480),
    const Size(700, 400),
  ]) {
    testWidgets('pre-join preview and controls fit at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpScreen(
        tester,
        getSessionToken: () async => throw Exception('join unavailable'),
      );

      check(find.byType(PreJoinView).evaluate()).isNotEmpty();
      check(find.byType(LocalParticipantCard).evaluate()).isNotEmpty();
      check(find.byType(ActionSliderButton).evaluate()).isNotEmpty();
      check(tester.takeException()).isNull();
      await tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .onActionCompleted();
      await tester.pump();
      check(find.textContaining('Please try again:').evaluate()).isNotEmpty();
      check(tester.takeException()).isNull();
    });
  }

  testWidgets('pre-join preview defers the token until Join', (
    tester,
  ) async {
    var tokenRequests = 0;
    final token = Completer<JoinResponse>();
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      trackFactory: factory,
      getSessionToken: () {
        tokenRequests++;
        return token.future;
      },
    );

    check(find.byType(PreJoinView).evaluate()).isNotEmpty();
    check(find.byType(LocalParticipantCard).evaluate()).isNotEmpty();
    check(tokenRequests).equals(0);
    check(factory.videoTracks).length.equals(1);
    check(factory.audioTracks).length.equals(1);

    final joining = tester
        .widget<ActionSliderButton>(find.byType(ActionSliderButton))
        .onActionCompleted();
    await tester.pump();
    check(tokenRequests).equals(1);
    token.completeError(StateError('Test token request canceled'));
    await joining;
  });

  testWidgets(
    'locks media toggles during initial capture',
    (tester) async {
      final factory = _DelayedTrackFactory();
      await pumpScreen(
        tester,
        waitingForAdmission: true,
        trackFactory: factory,
      );

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

  group('media access', () {
    bool joinEnabled(WidgetTester tester) => tester
        .widget<ActionSliderButton>(find.byType(ActionSliderButton))
        .enabled;

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('X1: already granted needs no sheet and enables Join', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      check(find.byType(MediaPrimingSheet).evaluate()).isEmpty();
      check(find.byType(MediaRecoveryBanner).evaluate()).isEmpty();
      check(joinEnabled(tester)).isTrue();
    });

    testWidgets('X2: unknown access shows the priming sheet first', (
      tester,
    ) async {
      final factory = _TrackFactory();
      await pumpScreen(
        tester,
        trackFactory: factory,
        adapter: FakeMediaPermissionAdapter(
          camera: MediaPermission.unknown,
          microphone: MediaPermission.unknown,
        ),
      );
      await settle(tester);

      check(find.byType(MediaPrimingSheet).evaluate()).length.equals(1);
      check(factory.videoTracks).isEmpty();
      check(factory.audioTracks).isEmpty();
      check(joinEnabled(tester)).isFalse();
    });

    testWidgets('X5: granting from the sheet starts the preview and Join', (
      tester,
    ) async {
      final factory = _TrackFactory();
      await pumpScreen(
        tester,
        trackFactory: factory,
        adapter: FakeMediaPermissionAdapter(
          camera: MediaPermission.unknown,
          microphone: MediaPermission.unknown,
          requestResults: {MediaKind.microphone: MediaPermission.granted},
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Microphone'));
      await settle(tester);

      check(factory.audioTracks).length.equals(1);
      check(factory.videoTracks).isEmpty();
      await tester.tap(find.text('Continue'));
      await settle(tester);
      check(joinEnabled(tester)).isTrue();
    });

    testWidgets("X2: the sheet's main action asks for the microphone", (
      tester,
    ) async {
      Finder inSheet(String text) => find.descendant(
        of: find.byType(MediaPrimingSheet),
        matching: find.text(text),
      );
      final adapter = FakeMediaPermissionAdapter(
        camera: MediaPermission.unknown,
        microphone: MediaPermission.unknown,
        requestResults: {MediaKind.microphone: MediaPermission.granted},
      );
      await pumpScreen(tester, adapter: adapter);
      await settle(tester);
      check(inSheet('Not now').evaluate()).length.equals(1);

      await tester.tap(inSheet('Allow microphone'));
      await settle(tester);

      check(adapter.requested).deepEquals([MediaKind.microphone]);
      check(inSheet('Not now').evaluate()).isEmpty();
      await tester.tap(inSheet('Continue'));
      await settle(tester);
      check(find.byType(MediaPrimingSheet).evaluate()).isEmpty();
      check(joinEnabled(tester)).isTrue();
    });

    testWidgets('X2: turning on a waiting mic asks and captures once', (
      tester,
    ) async {
      final factory = _TrackFactory();
      final adapter = FakeMediaPermissionAdapter(
        microphone: MediaPermission.unknown,
        requestResults: {MediaKind.microphone: MediaPermission.granted},
      );
      await pumpScreen(tester, trackFactory: factory, adapter: adapter);
      await settle(tester);
      await tester.tap(find.text('Not now'));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^Microphone off')));
      await settle(tester);

      check(adapter.requested).deepEquals([MediaKind.microphone]);
      check(factory.audioTracks).length.equals(1);
      check(joinEnabled(tester)).isTrue();
    });

    testWidgets('X3: a refused camera still allows joining', (tester) async {
      await pumpScreen(
        tester,
        adapter: FakeMediaPermissionAdapter(camera: MediaPermission.blocked),
      );
      await settle(tester);

      check(find.byType(MediaPrimingSheet).evaluate()).isEmpty();
      check(joinEnabled(tester)).isTrue();
    });

    testWidgets('X4: the mic toggle relies on the banner, not a dialog', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        adapter: FakeMediaPermissionAdapter(
          microphone: MediaPermission.blocked,
        ),
      );
      await settle(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^Microphone off')));
      await settle(tester);

      check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
      check(find.byType(MediaRecoveryBanner).evaluate()).length.equals(1);
    });

    testWidgets('X4: the microphone fix fits a small phone', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(
        tester,
        adapter: FakeMediaPermissionAdapter(
          microphone: MediaPermission.blocked,
        ),
      );
      await settle(tester);

      check(find.byType(MediaRecoveryBanner).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('a prompt answered after leaving pre-join is ignored', (
      tester,
    ) async {
      final adapter = FakeMediaPermissionAdapter(
        camera: MediaPermission.unknown,
        requestResults: {MediaKind.camera: MediaPermission.granted},
      )..requestGate = Completer();
      await pumpScreen(tester, adapter: adapter);
      await settle(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^Camera off')));
      await tester.pump();
      check(adapter.requested).deepEquals([MediaKind.camera]);

      await tester.pumpWidget(const SizedBox.shrink());
      adapter.requestGate!.complete();
      await tester.pump();

      check(tester.takeException()).isNull();
    });

    testWidgets('X7: a blocked camera toggle explains the fix', (tester) async {
      await pumpScreen(
        tester,
        adapter: FakeMediaPermissionAdapter(camera: MediaPermission.blocked),
      );
      await settle(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^Camera off')));
      await settle(tester);

      check(find.byType(MediaRecoveryDialog).evaluate()).length.equals(1);
    });

    testWidgets('priming tiles only act when a tap can fix the device', (
      tester,
    ) async {
      final adapter = FakeMediaPermissionAdapter(
        camera: MediaPermission.restricted,
        microphone: MediaPermission.unknown,
      );
      await pumpScreen(tester, adapter: adapter);
      await settle(tester);

      await tester.tap(find.text('Camera'));
      await settle(tester);
      check(adapter.settingsOpened).equals(0);
      check(adapter.requested).isEmpty();

      await tester.tap(find.text('Microphone'));
      await settle(tester);
      check(adapter.requested).deepEquals([MediaKind.microphone]);
    });

    testWidgets('X2: an ended session shows no priming sheet', (tester) async {
      await pumpScreen(
        tester,
        sessionEnded: true,
        adapter: FakeMediaPermissionAdapter(
          camera: MediaPermission.unknown,
          microphone: MediaPermission.unknown,
        ),
      );
      await settle(tester);

      check(find.byType(MediaPrimingSheet).evaluate()).isEmpty();
    });

    testWidgets('X2: permission priming precedes the join token request', (
      tester,
    ) async {
      var tokenRequests = 0;
      await pumpScreen(
        tester,
        getSessionToken: () {
          tokenRequests++;
          throw Exception('token failed');
        },
        adapter: FakeMediaPermissionAdapter(
          camera: MediaPermission.unknown,
          microphone: MediaPermission.unknown,
        ),
      );
      await settle(tester);

      check(find.byType(MediaPrimingSheet).evaluate()).isNotEmpty();
      check(tokenRequests).equals(0);
    });

    testWidgets('X2: an unanswered camera alone brings no sheet back', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        adapter: FakeMediaPermissionAdapter(camera: MediaPermission.unknown),
      );
      await settle(tester);

      check(find.byType(MediaPrimingSheet).evaluate()).isEmpty();
      check(joinEnabled(tester)).isTrue();
    });

    testWidgets('A2: a tile Android stops asking for points to Settings', (
      tester,
    ) async {
      final adapter = FakeMediaPermissionAdapter(
        microphone: MediaPermission.denied,
        requestResults: {MediaKind.microphone: MediaPermission.blocked},
      );
      await pumpScreen(tester, adapter: adapter, platform: const AndroidApp());
      await settle(tester);

      await tester.tap(find.text('Microphone'));
      await settle(tester);
      check(adapter.requested).deepEquals([MediaKind.microphone]);
      check(
        find.text("It's off in Settings. Tap to change it.").evaluate(),
      ).length.equals(1);

      await tester.tap(find.text('Microphone'));
      await settle(tester);
      check(adapter.settingsOpened).equals(1);
    });

    testWidgets('X4: a blocked microphone shows its fix and disables Join', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        adapter: FakeMediaPermissionAdapter(
          microphone: MediaPermission.blocked,
        ),
      );
      await settle(tester);

      check(find.byType(MediaRecoveryBanner).evaluate()).length.equals(1);
      check(find.text('Open Settings').evaluate()).length.equals(1);
      check(joinEnabled(tester)).isFalse();
    });
  });

  testWidgets('token failures offer a retry after Join', (tester) async {
    var tokenRequests = 0;
    await pumpScreen(
      tester,
      getSessionToken: () async {
        tokenRequests++;
        throw Exception('token failed');
      },
    );

    check(tokenRequests).equals(0);
    check(find.byType(PreJoinView).evaluate()).isNotEmpty();
    await tester
        .widget<ActionSliderButton>(find.byType(ActionSliderButton))
        .onActionCompleted();
    await tester.pump();
    await tester.pump();

    check(tokenRequests).equals(1);
    check(find.textContaining('Please try again:').evaluate()).isNotEmpty();
    check(find.byType(PreJoinView).evaluate()).isNotEmpty();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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

    unawaited(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .onActionCompleted(),
    );
    await tester.pump();
    await tester.pump();

    check(tester.widgetList(find.byType(VideoSessionScreen))).length.equals(1);
  });

  testWidgets('transitions while the room connection is still pending', (
    tester,
  ) async {
    _PendingSessionController.joinCompleter = Completer<SessionJoinResult>();
    final factory = _TrackFactory();
    await pumpScreen(tester, pendingJoin: true, trackFactory: factory);
    check(factory.videoTracks).length.equals(1);

    unawaited(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .onActionCompleted(),
    );
    await tester.pump();
    await tester.pump();

    check(tester.widgetList(find.byType(VideoSessionScreen))).length.equals(1);
    check(find.byType(VideoTrackRenderer).evaluate()).isNotEmpty();
    check(factory.videoTracks).length.equals(1);

    _PendingSessionController.joinCompleter!.complete(
      SessionJoinResult.success,
    );
    await tester.pump();
    check(factory.videoTracks).length.equals(1);
  });

  testWidgets('shows replacement confirmation only after joining', (
    tester,
  ) async {
    await pumpScreen(tester, alreadyPresent: true, successfulJoin: true);
    await tester.pump(const Duration(milliseconds: 300));

    check(
      tester.widgetList(find.text("You're already in this session")),
    ).length.equals(0);

    unawaited(
      tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .onActionCompleted(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    check(
      tester.widgetList(find.text("You're already in this session")),
    ).length.equals(1);
    check(tester.widgetList(find.text('Join Here'))).length.equals(1);

    await tester.tap(find.text('Join Here'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    check(
      tester.widgetList(find.text("You're already in this session")),
    ).length.equals(0);
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
