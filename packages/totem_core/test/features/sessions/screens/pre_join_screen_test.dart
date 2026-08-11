import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart'
    as sessions;
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/loading_screen.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
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
    speakerEnabled: true,
    cameraOptions: sessions.SessionController.defaultCameraCaptureOptions,
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

class _DelayedCameraPreviewTrackFactory extends _PreviewTrackFactory {
  final cameraGate = Completer<void>();
  bool cameraRequestStarted = false;

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    cameraRequestStarted = true;
    await cameraGate.future;
    return super.createVideoTrack(cameraOptions);
  }
}

class _DelayedMicrophonePreviewTrackFactory extends _PreviewTrackFactory {
  final microphoneGate = Completer<void>();
  bool microphoneRequestStarted = false;

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    microphoneRequestStarted = true;
    await microphoneGate.future;
    return super.createAudioTrack();
  }
}

class _UnavailableCameraPreviewTrackFactory extends _PreviewTrackFactory {
  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    throw Exception('NotFoundError: no camera is available');
  }
}

class _NoOpSessionController extends sessions.SessionController {
  static session_state.SessionJoinMedia? lastJoinMedia;

  @override
  session_state.SessionRoomState build(session_state.SessionOptions options) {
    return _createConnectedSessionState();
  }

  @override
  Future<sessions.SessionJoinResult> join({
    session_state.SessionJoinMedia? joinMedia,
  }) async {
    lastJoinMedia = joinMedia;
    return sessions.SessionJoinResult.success;
  }
}

class _FailOnceSessionController extends sessions.SessionController {
  static final joinMedia = <session_state.SessionJoinMedia?>[];
  static int resetCount = 0;

  static void reset() {
    joinMedia.clear();
    resetCount = 0;
  }

  @override
  session_state.SessionRoomState build(session_state.SessionOptions options) {
    return _createConnectedSessionState();
  }

  @override
  Future<sessions.SessionJoinResult> join({
    session_state.SessionJoinMedia? joinMedia,
  }) async {
    _FailOnceSessionController.joinMedia.add(joinMedia);
    return _FailOnceSessionController.joinMedia.length > 1
        ? sessions.SessionJoinResult.success
        : sessions.SessionJoinResult.retryableFailure;
  }

  @override
  Future<void> resetAfterFailedJoin() async {
    resetCount++;
  }
}

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

  Future<void> pumpPreJoinScreen(
    WidgetTester tester, {
    JoinResponse? joinResponse,
    Exception? tokenError,
    SessionDetailSchema? event,
    Exception? eventError,
    PreJoinPreviewTrackFactory? previewTrackFactory,
    bool useNoOpSessionController = false,
    bool useFailOnceSessionController = false,
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
          if (useNoOpSessionController)
            sessions
                .sessionControllerProvider(_createSessionOptions())
                .overrideWith(_NoOpSessionController.new),
          if (useFailOnceSessionController)
            sessions
                .sessionControllerProvider(_createSessionOptions())
                .overrideWith(_FailOnceSessionController.new),
          eventProvider(sessionSlug).overrideWith((ref) async {
            if (eventError != null) {
              throw eventError;
            }
            return sessionEvent;
          }),
          if (tokenError != null || eventError != null)
            currentSessionStateProvider.overrideWithValue(null),
          if (tokenError != null || eventError != null)
            getRecommendedSessionsProvider().overrideWith(
              (ref) => <SessionDetailSchema>[],
            ),
          if (tokenError != null || eventError != null)
            spacesSummaryProvider.overrideWith(
              (ref) => throw UnimplementedError(),
            ),
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
    await tester.pump();
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

  group('PreJoinMediaOperationQueue', () {
    test(
      'continues after a failed operation without hiding its error',
      () async {
        final queue = PreJoinMediaOperationQueue();

        final failedOperation = queue.schedule<void>(
          () async => throw StateError('media operation failed'),
        );

        await expectLater(failedOperation, throwsStateError);
        await expectLater(queue.pending, completes);

        var nextOperationRan = false;
        final result = await queue.schedule<int>(() async {
          nextOperationRan = true;
          return 42;
        });

        expect(nextOperationRan, isTrue);
        expect(result, 42);
        await expectLater(queue.pending, completes);
      },
    );
  });

  group('PreJoinMediaStatus', () {
    for (final cameraError in [
      'NotFoundError: no camera',
      'NotReadableError: camera is busy',
      'OverconstrainedError: stale deviceId',
    ]) {
      test('allows a microphone-only web join for $cameraError', () {
        final status = PreJoinMediaStatus(
          cameraInitializationComplete: true,
          microphoneInitializationComplete: true,
          cameraPermissionGranted: false,
          microphonePermissionGranted: true,
          cameraError: cameraError,
        );

        expect(status.requiredPermissionsGranted, isFalse);
        expect(status.canJoinOnWeb, isTrue);
      });
    }

    test('blocks a web join when camera permission was explicitly denied', () {
      const status = PreJoinMediaStatus(
        cameraInitializationComplete: true,
        microphoneInitializationComplete: true,
        cameraPermissionGranted: false,
        microphonePermissionGranted: true,
        cameraError: 'NotAllowedError: permission denied',
      );

      expect(status.canJoinOnWeb, isFalse);
    });
  });

  group('PreJoinScreen', () {
    group('renders', () {
      testWidgets('renders the pre-join controls', (tester) async {
        await pumpPreJoinScreen(tester);

        expect(find.byType(ActionBar), findsOneWidget);
        expect(find.byType(ActionSliderButton), findsOneWidget);
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
        AsyncValueGetter<JoinResponse> loadToken = () async =>
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
        expect(find.byType(ActionSliderButton), findsOneWidget);
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

      testWidgets(
        'shows error screen for notFound RoomErrorResponse (non-web fallback)',
        (tester) async {
          const notFoundError = ApiError<JoinResponse, RoomErrorResponse>(
            statusCode: 404,
            error: RoomErrorResponse(
              code: ErrorCode.notFound,
              message: 'Session not found',
            ),
          );

          await pumpPreJoinScreen(
            tester,
            tokenError: notFoundError,
          );
          // Pump enough time for SessionDisconnectedScreen's Future.delayed
          // (2750ms) to fire and complete.
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();

          // On non-web (test environment), the error screen is shown.
          expect(find.byType(SessionErrorScreen), findsOneWidget);
        },
      );

      testWidgets(
        'notFound error does not render the pre-join camera/mic controls',
        (tester) async {
          const notFoundError = ApiError<JoinResponse, RoomErrorResponse>(
            statusCode: 404,
            error: RoomErrorResponse(
              code: ErrorCode.notFound,
              message: 'Session not found',
            ),
          );

          await pumpPreJoinScreen(
            tester,
            tokenError: notFoundError,
          );
          // Pump enough time for SessionDisconnectedScreen's Future.delayed
          // (2750ms) to fire and complete.
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();

          // Camera and microphone controls must not be shown.
          expect(
            find.byType(ActionBarCameraSwitcherButton),
            findsNothing,
          );
          expect(find.byType(ActionBarMicButton), findsNothing);
        },
      );
    });

    group('preview controls', () {
      testWidgets(
        'falls back to microphone-only when the camera is unavailable',
        (tester) async {
          final previewTracks = _UnavailableCameraPreviewTrackFactory();
          final mediaController = PreJoinMediaController();
          final preferences = <MediaPreferences>[];
          final statuses = <PreJoinMediaStatus>[];

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
              ],
              child: MaterialApp(
                home: PrejoinSessionScreen(
                  previewTrackFactory: previewTracks,
                  mediaController: mediaController,
                  onMediaPreferencesChanged: preferences.add,
                  onMediaStatusChanged: statuses.add,
                ),
              ),
            ),
          );

          for (var i = 0; i < 10; i++) {
            await tester.pump();
          }

          expect(previewTracks.audioTracks, hasLength(1));
          expect(preferences.last.isCameraOn, isFalse);
          expect(preferences.last.isMicOn, isTrue);
          expect(statuses.last.canJoinOnWeb, isTrue);

          final joinMedia = await mediaController.takeForJoin();
          expect(joinMedia.cameraTrack, isNull);
          expect(
            joinMedia.microphoneTrack,
            same(previewTracks.audioTracks.single),
          );
        },
      );

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

      testWidgets('toggles the microphone preview and disposes the track', (
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

        expect(previewTracks.audioTracks, hasLength(1));
        verify(firstTrack.stop).called(1);
        verify(firstTrack.dispose).called(1);

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
        verify(
          () => previewTracks.audioTracks.last.unmute(stopOnMute: false),
        ).called(1);
      });

      testWidgets(
        'does not acquire microphone when disabled during camera initialization',
        (tester) async {
          final previewTracks = _DelayedCameraPreviewTrackFactory();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
              ],
              child: MaterialApp(
                home: PrejoinSessionScreen(
                  previewTrackFactory: previewTracks,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(previewTracks.cameraRequestStarted, isTrue);
          expect(previewTracks.audioTracks, isEmpty);

          await tester.tap(find.byType(ActionBarMicButton));
          await tester.pump();
          previewTracks.cameraGate.complete();
          for (var i = 0; i < 5; i++) {
            await tester.pump();
          }

          expect(previewTracks.videoTracks, hasLength(1));
          expect(previewTracks.audioTracks, isEmpty);
          expect(
            tester
                .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
                .audioTrack,
            isNull,
          );
        },
      );

      testWidgets(
        'microphone stop waits for in-flight initialization',
        (tester) async {
          final previewTracks = _DelayedMicrophonePreviewTrackFactory();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
              ],
              child: MaterialApp(
                home: PrejoinSessionScreen(
                  previewTrackFactory: previewTracks,
                ),
              ),
            ),
          );
          for (var i = 0; i < 5; i++) {
            await tester.pump();
          }

          expect(previewTracks.microphoneRequestStarted, isTrue);
          expect(previewTracks.audioTracks, isEmpty);

          await tester.tap(find.byType(ActionBarMicButton));
          await tester.pump();
          previewTracks.microphoneGate.complete();
          for (var i = 0; i < 5; i++) {
            await tester.pump();
          }

          final createdTrack = previewTracks.audioTracks.single;
          verify(createdTrack.stop).called(1);
          verify(createdTrack.dispose).called(1);
          expect(
            tester
                .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
                .audioTrack,
            isNull,
          );
        },
      );

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

      testWidgets(
        'transfers the existing preview tracks without disposing them',
        (tester) async {
          final previewTracks = _PreviewTrackFactory();
          final mediaController = PreJoinMediaController();
          final statuses = <PreJoinMediaStatus>[];

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
              ],
              child: MaterialApp(
                home: PrejoinSessionScreen(
                  previewTrackFactory: previewTracks,
                  mediaController: mediaController,
                  onMediaStatusChanged: statuses.add,
                ),
              ),
            ),
          );

          await pumpUntilPreviewTracksReady(tester, previewTracks);
          await tester.pump();

          final videoTrack = previewTracks.videoTracks.single;
          final audioTrack = previewTracks.audioTracks.single;
          final joinMedia = await mediaController.takeForJoin();

          expect(joinMedia.cameraTrack, same(videoTrack));
          expect(joinMedia.microphoneTrack, same(audioTrack));
          expect(statuses.last.initializationComplete, isTrue);
          expect(statuses.last.requiredPermissionsGranted, isTrue);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();

          verifyNever(videoTrack.stop);
          verifyNever(videoTrack.dispose);
          verifyNever(audioTrack.stop);
          verifyNever(audioTrack.dispose);
          expect(previewTracks.videoTracks, hasLength(1));
          expect(previewTracks.audioTracks, hasLength(1));
        },
      );

      testWidgets(
        'creates fresh preview tracks after a failed join transfer',
        (tester) async {
          final previewTracks = _PreviewTrackFactory();
          final mediaController = PreJoinMediaController();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
              ],
              child: MaterialApp(
                home: PrejoinSessionScreen(
                  previewTrackFactory: previewTracks,
                  mediaController: mediaController,
                ),
              ),
            ),
          );

          await pumpUntilPreviewTracksReady(tester, previewTracks);
          final firstMedia = await mediaController.takeForJoin();

          final status = await mediaController.resetAfterFailedJoin();
          await tester.pump();

          expect(status.requiredPermissionsGranted, isTrue);
          expect(previewTracks.videoTracks, hasLength(2));
          expect(previewTracks.audioTracks, hasLength(2));

          final secondMedia = await mediaController.takeForJoin();
          expect(secondMedia.cameraTrack, same(previewTracks.videoTracks.last));
          expect(
            secondMedia.microphoneTrack,
            same(previewTracks.audioTracks.last),
          );
          expect(secondMedia.cameraTrack, isNot(same(firstMedia.cameraTrack)));
          expect(
            secondMedia.microphoneTrack,
            isNot(same(firstMedia.microphoneTrack)),
          );
          verifyNever(firstMedia.cameraTrack!.stop);
          verifyNever(firstMedia.cameraTrack!.dispose);
          verifyNever(firstMedia.microphoneTrack!.stop);
          verifyNever(firstMedia.microphoneTrack!.dispose);
        },
      );

      testWidgets(
        'allows a second join attempt with fresh tracks after failure',
        (tester) async {
          final previewTracks = _PreviewTrackFactory();
          _FailOnceSessionController.reset();

          await pumpPreJoinScreen(
            tester,
            useFailOnceSessionController: true,
            previewTrackFactory: previewTracks,
          );
          await pumpUntilPreviewTracksReady(tester, previewTracks);

          Future<void> requestJoin() async {
            final sliderFinder = find.byType(ActionSlider);
            final buttonFinder = find.byType(ActionButton);
            if (sliderFinder.evaluate().isNotEmpty) {
              await tester.drag(
                sliderFinder.first,
                const Offset(600, 0),
                warnIfMissed: false,
              );
            } else {
              await tester.tap(buttonFinder.first);
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            await tester.pump(const Duration(milliseconds: 250));
          }

          await requestJoin();

          expect(_FailOnceSessionController.joinMedia, hasLength(1));
          expect(_FailOnceSessionController.resetCount, 1);
          expect(previewTracks.videoTracks, hasLength(2));
          expect(previewTracks.audioTracks, hasLength(2));
          expect(find.byType(ActionSliderButton), findsOneWidget);

          await requestJoin();

          expect(_FailOnceSessionController.joinMedia, hasLength(2));
          expect(
            _FailOnceSessionController.joinMedia.last?.cameraTrack,
            same(previewTracks.videoTracks.last),
          );
          expect(
            _FailOnceSessionController.joinMedia.last?.microphoneTrack,
            same(previewTracks.audioTracks.last),
          );
        },
      );

      testWidgets(
        'does not allow changing action bar items after join is requested',
        (tester) async {
          final previewTracks = _PreviewTrackFactory();
          _NoOpSessionController.lastJoinMedia = null;

          await pumpPreJoinScreen(
            tester,
            useNoOpSessionController: true,
            previewTrackFactory: previewTracks,
          );
          await pumpUntilPreviewTracksReady(tester, previewTracks);

          expect(
            tester
                .widget<ActionBarMicButton>(find.byType(ActionBarMicButton))
                .onToggle,
            isNotNull,
          );
          final initialSpeakerButton = tester
              .widgetList<ActionBarButton>(find.byType(ActionBarButton))
              .firstWhere(
                (button) => (button.semanticsLabel ?? '').startsWith('Audio '),
              );
          expect(
            initialSpeakerButton.onPressed,
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

          final sliderFinder = find.byType(ActionSlider);
          final buttonFinder = find.byType(ActionButton);
          if (sliderFinder.evaluate().isNotEmpty) {
            await tester.drag(
              sliderFinder.first,
              const Offset(500, 0),
              warnIfMissed: false,
            );
          } else {
            await tester.tap(buttonFinder.first);
          }
          await tester.pump();

          expect(
            _NoOpSessionController.lastJoinMedia?.cameraTrack,
            same(previewTracks.videoTracks.single),
          );
          expect(
            _NoOpSessionController.lastJoinMedia?.microphoneTrack,
            same(previewTracks.audioTracks.single),
          );

          expect(
            tester
                .widgetList<ActionBarMicButton>(find.byType(ActionBarMicButton))
                .every((button) => button.onToggle == null),
            isTrue,
          );
          final speakerButtons = tester
              .widgetList<ActionBarButton>(find.byType(ActionBarButton))
              .where(
                (button) => (button.semanticsLabel ?? '').startsWith('Audio '),
              );
          expect(
            speakerButtons.every((button) => button.onPressed == null),
            isTrue,
          );
          expect(
            tester
                .widgetList<ActionBarCameraSwitcherButton>(
                  find.byType(ActionBarCameraSwitcherButton),
                )
                .every((button) => button.onToggle == null),
            isTrue,
          );
        },
      );
    });

    group('already-present dialog', () {
      testWidgets('shows the already-present dialog when token says so', (
        tester,
      ) async {
        await pumpPreJoinScreen(
          tester,
          joinResponse: _createJoinResponse(isAlreadyPresent: true),
        );

        final sliderFinder = find.byType(ActionSlider);
        final buttonFinder = find.byType(ActionButton);
        if (sliderFinder.evaluate().isNotEmpty) {
          await tester.drag(
            sliderFinder.first,
            const Offset(600, 0),
            warnIfMissed: false,
          );
        } else {
          await tester.tap(buttonFinder.first);
        }
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
