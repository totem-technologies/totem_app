import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart'
    as sessions;
import 'package:totem_app/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../mocks/flutter_foreground_task_mock.dart';
import '../../../mocks/permission_handler_mock.dart';
import '../../../setup.dart';
import '../livekit_mocks.dart';

const sessionSlug = 'test-session';

SessionDetailSchema _createSessionEvent({
  required DateTime start,
  required int duration,
  String slug = sessionSlug,
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

JoinResponse _createJoinResponse({bool isAlreadyPresent = false}) {
  return JoinResponse(
    token: 'test-token',
    isAlreadyPresent: isAlreadyPresent,
  );
}

session_state.SessionOptions _createSessionOptions() {
  return const session_state.SessionOptions(
    eventSlug: sessionSlug,
    token: 'test-token',
    cameraEnabled: true,
    microphoneEnabled: true,
    cameraOptions: sessions.SessionController.defaultCameraCaptureOptions,
    audioOutputOptions: AudioOutputOptions(speakerOn: true),
  );
}

session_state.SessionRoomState _createConnectedSessionState() {
  return const session_state.SessionRoomState(
    connection: session_state.ConnectionState(
      phase: session_state.SessionPhase.connected,
      state: session_state.RoomConnectionState.connected,
    ),
    participants: session_state.ParticipantsState(),
    chat: session_state.ChatState(),
    turn: session_state.SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: '',
        currentSpeaker: '',
        status: RoomStatus.waitingRoom,
        turnState: TurnState.idle,
        sessionSlug: sessionSlug,
        statusDetail: RoomStateStatusDetailWaitingRoom(
          WaitingRoomDetail(),
        ),
        talkingOrder: <String>[],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

class _PreviewTrackFactory extends PreJoinPreviewTrackFactory {
  final videoTracks = <MockLocalVideoTrack>[];
  final audioTracks = <MockLocalAudioTrack>[];

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    final track = MockLocalVideoTrack();
    when(() => track.isActive).thenReturn(true);
    when(() => track.muted).thenReturn(false);
    when(track.start).thenAnswer((_) async => true);
    when(track.stop).thenAnswer((_) async => true);
    when(track.dispose).thenAnswer((_) async => true);
    videoTracks.add(track);
    return track;
  }

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    final track = MockLocalAudioTrack();
    when(track.createListener).thenReturn(MockTrackEventsListener());
    audioTracks.add(track);
    return track;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupDotenv();
    silenceLogger();
    setupMockFlutterForegroundTask();
    setupMockPermissionHandler();
  });

  tearDownAll(() {
    clearMockFlutterForegroundTask();
    clearMockPermissionHandler();
  });

  Future<void> pumpPreJoinScreen(
    WidgetTester tester, {
    JoinResponse? joinResponse,
    Exception? tokenError,
    SessionDetailSchema? event,
    Exception? eventError,
    PreJoinPreviewTrackFactory? previewTrackFactory,
  }) async {
    final sessionEvent =
        event ??
        _createSessionEvent(
          start: DateTime(2024, 1, 1, 10),
          duration: 60,
          slug: sessionSlug,
        );
    final screen = previewTrackFactory == null
        ? const PreJoinScreen(sessionSlug: sessionSlug)
        : PreJoinScreen(
            sessionSlug: sessionSlug,
            previewTrackFactory: previewTrackFactory,
          );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          sessionTokenProvider(sessionSlug).overrideWith((ref) async {
            if (tokenError != null) {
              throw tokenError;
            }
            return joinResponse ?? _createJoinResponse();
          }),
          if (eventError != null)
            sessions
                .sessionProvider(_createSessionOptions())
                .overrideWithValue(
                  _createConnectedSessionState(),
                ),
          eventProvider(sessionSlug).overrideWith((ref) async {
            if (eventError != null) {
              throw eventError;
            }
            return sessionEvent;
          }),
        ],
        child: SentryDisplayWidget(
          child: MaterialApp(
            home: screen,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> pumpUntilPreviewTracksReady(
    WidgetTester tester,
    _PreviewTrackFactory previewTracks,
  ) async {
    for (var i = 0; i < 20; i++) {
      if (previewTracks.videoTracks.isNotEmpty &&
          previewTracks.audioTracks.isNotEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<BuildContext> pumpDialogHost(
    WidgetTester tester, {
    bool withNavigator = true,
  }) async {
    BuildContext? capturedContext;

    await tester.pumpWidget(
      withNavigator
          ? MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            )
          : Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  capturedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
    );

    return capturedContext!;
  }

  group('PreJoinScreen', () {
    group('renders', () {
      testWidgets('renders the pre-join controls', (tester) async {
        await pumpPreJoinScreen(tester);

        expect(find.byType(ActionBar), findsOneWidget);
        expect(find.text('Swipe to Join'), findsOneWidget);
        expect(find.text('Welcome'), findsOneWidget);
      });
    });

    group('errors', () {
      testWidgets('shows the token error screen when the token load fails', (
        tester,
      ) async {
        await pumpPreJoinScreen(
          tester,
          tokenError: Exception('token failed'),
        );

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retries and recovers after an initial token failure', (
        tester,
      ) async {
        Future<JoinResponse> Function() loadToken = () async =>
            throw Exception('token failed');
        var tokenAttempts = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => FakeAuthController(AuthState.unauthenticated()),
              ),
              sessionTokenProvider(sessionSlug).overrideWith((ref) async {
                tokenAttempts += 1;
                return loadToken();
              }),
              eventProvider(sessionSlug).overrideWith((ref) async {
                return _createSessionEvent(
                  start: DateTime(2024, 1, 1, 10),
                  duration: 60,
                  slug: sessionSlug,
                );
              }),
            ],
            child: const SentryDisplayWidget(
              child: MaterialApp(
                home: PreJoinScreen(sessionSlug: sessionSlug),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        loadToken = () async => _createJoinResponse();

        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        expect(tokenAttempts, greaterThanOrEqualTo(2));
        expect(find.text('Something went wrong'), findsNothing);
        expect(find.text('Swipe to Join'), findsOneWidget);
        expect(find.text('Welcome'), findsOneWidget);
      });

      testWidgets('shows the event error screen when the event load fails', (
        tester,
      ) async {
        await pumpPreJoinScreen(
          tester,
          eventError: Exception('event failed'),
        );

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('preview controls', () {
      testWidgets('toggles the camera preview state', (tester) async {
        final previewTracks = _PreviewTrackFactory();

        await pumpPreJoinScreen(
          tester,
          previewTrackFactory: previewTracks,
        );

        await pumpUntilPreviewTracksReady(tester, previewTracks);

        final cameraButton = tester.widget<ActionBarCameraSwitcherButton>(
          find.byType(ActionBarCameraSwitcherButton),
        );
        expect(cameraButton.isCameraOn, isTrue);

        await tester.tap(find.byType(ActionBarCameraSwitcherButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        final toggledCameraButton = tester
            .widget<ActionBarCameraSwitcherButton>(
              find.byType(ActionBarCameraSwitcherButton),
            );
        expect(toggledCameraButton.isCameraOn, isFalse);
        expect(previewTracks.videoTracks, hasLength(1));
      });

      testWidgets('toggles the microphone preview and recreates the track', (
        tester,
      ) async {
        final previewTracks = _PreviewTrackFactory();

        await pumpPreJoinScreen(
          tester,
          previewTrackFactory: previewTracks,
        );

        await pumpUntilPreviewTracksReady(tester, previewTracks);

        expect(previewTracks.audioTracks, hasLength(1));

        final firstTrack = previewTracks.audioTracks.single;

        await tester.tap(find.byType(ActionBarMicButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        expect(previewTracks.audioTracks, hasLength(2));
        expect(
          tester
              .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
              .audioTrack,
          same(previewTracks.audioTracks.last),
        );
        verify(firstTrack.stop).called(1);
        verify(firstTrack.dispose).called(1);
        verify(
          () => previewTracks.audioTracks.last.mute(stopOnMute: false),
        ).called(1);

        await tester.tap(find.byType(ActionBarMicButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        expect(previewTracks.audioTracks, hasLength(3));
        expect(
          tester
              .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
              .audioTrack,
          same(previewTracks.audioTracks.last),
        );
        verify(() => previewTracks.audioTracks[1].stop()).called(1);
        verify(() => previewTracks.audioTracks[1].dispose()).called(1);
        verify(
          () => previewTracks.audioTracks.last.unmute(stopOnMute: false),
        ).called(1);
      });

      testWidgets('disposes preview tracks when the screen is removed', (
        tester,
      ) async {
        final previewTracks = _PreviewTrackFactory();

        await pumpPreJoinScreen(
          tester,
          previewTrackFactory: previewTracks,
        );

        await pumpUntilPreviewTracksReady(tester, previewTracks);

        final videoTrack = previewTracks.videoTracks.single;
        final audioTrack = previewTracks.audioTracks.single;

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        verify(videoTrack.stop).called(1);
        verify(videoTrack.dispose).called(1);
        verify(audioTrack.stop).called(1);
        verify(audioTrack.dispose).called(1);
      });
    });

    group('already-present dialog', () {
      testWidgets('shows the already-present dialog when token says so', (
        tester,
      ) async {
        await pumpPreJoinScreen(
          tester,
          joinResponse: _createJoinResponse(isAlreadyPresent: true),
        );

        await tester.drag(find.text('Swipe to Join'), const Offset(600, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.text("You're Already in This Session"),
          findsOneWidget,
        );
        expect(
          find.text(
            'You are already in this session on another device. Do you want to leave the other session and join on this device?',
          ),
          findsOneWidget,
        );
        expect(find.text('Join Here'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('showAlreadyPresentDialog returns true on confirm', (
        tester,
      ) async {
        final context = await pumpDialogHost(tester);

        final dialogFuture = showAlreadyPresentDialog(context);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        await tester.tap(find.text('Join Here'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(await dialogFuture, isTrue);
      });

      testWidgets('showAlreadyPresentDialog returns false when it throws', (
        tester,
      ) async {
        final context = await pumpDialogHost(tester, withNavigator: false);

        await expectLater(showAlreadyPresentDialog(context), completion(false));
      });
    });
  });
}
