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
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_screen.dart';
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
    Future<JoinResponse> Function()? getSessionToken,
    Future<SessionDetailSchema> Function()? getSession,
    PreJoinPreviewTrackFactory? trackFactory,
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
            () => FakeAuthController(AuthState.unauthenticated()),
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
                Future.value(_event().copyWith(ended: sessionEnded)),
          ),
          if (successfulJoin) ...[
            sessionControllerProvider(
              _options,
            ).overrideWith(_SuccessfulSessionController.new),
          ],
          if (pendingJoin) ...[
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

  testWidgets('shows a disabled pre-join shell while checking eligibility', (
    tester,
  ) async {
    final token = Completer<JoinResponse>();
    final session = Completer<SessionDetailSchema>();
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      trackFactory: factory,
      getSessionToken: () => token.future,
      getSession: () => session.future,
    );

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

  testWidgets('terminal token errors do not create preview tracks', (
    tester,
  ) async {
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      trackFactory: factory,
      tokenError: const ApiError<JoinResponse, RoomErrorResponse>(
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

  testWidgets('terminal token error releases active preview tracks', (
    tester,
  ) async {
    Object? tokenError;
    final factory = _TrackFactory();
    await pumpScreen(
      tester,
      trackFactory: factory,
      getSessionToken: () async {
        // ApiError is the generated client's failure value and deliberately
        // does not implement Exception.
        // ignore: only_throw_errors
        if (tokenError != null) throw tokenError;
        return const JoinResponse(token: 'token', isAlreadyPresent: false);
      },
    );

    check(factory.videoTracks).length.equals(1);
    check(factory.audioTracks).length.equals(1);

    tokenError = const ApiError<JoinResponse, RoomErrorResponse>(
      statusCode: 409,
      error: RoomErrorResponse(
        code: ErrorCode.roomAlreadyEnded,
        message: 'Session already ended',
      ),
    );
    ProviderScope.containerOf(
      tester.element(find.byType(PreJoinScreen)),
    ).invalidate(sessionTokenProvider(_slug));
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

    testWidgets('X2: a failed token shows no priming sheet', (tester) async {
      await pumpScreen(
        tester,
        tokenError: Exception('token failed'),
        adapter: FakeMediaPermissionAdapter(
          camera: MediaPermission.unknown,
          microphone: MediaPermission.unknown,
        ),
      );
      await settle(tester);

      check(find.byType(MediaPrimingSheet).evaluate()).isEmpty();
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

  testWidgets('renders token failures through the session error screen', (
    tester,
  ) async {
    await pumpScreen(tester, tokenError: Exception('token failed'));

    check(tester.widgetList(find.byType(SessionErrorScreen))).length.equals(1);
    check(tester.widgetList(find.text('Try Joining Again'))).length.equals(1);
  });

  testWidgets('renders offline error when internet prevents joining', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      tokenError: Exception('token failed'),
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
    check(
      tester.element(find.byType(VideoTrackRenderer)),
    ).identicalTo(previewRenderer);

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

    check(
      tester.widgetList(find.text("You're already in this session")),
    ).length.equals(0);

    final join = tester.widget<ActionSliderButton>(
      find.byType(ActionSliderButton),
    );
    final joinFuture = join.onActionCompleted();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    check(
      tester.widgetList(find.text("You're already in this session")),
    ).length.equals(1);
    check(tester.widgetList(find.text('Join Here'))).length.equals(1);

    await tester.tap(find.text('Join Here'));
    await tester.pump();
    check(await joinFuture).equals(true);
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
