import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../setup.dart';
import '../livekit_mocks.dart';

const _slug = 'pre-join-flow-test';

SessionDetailSchema _event() => SessionDetailSchema(
  slug: _slug,
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

class _TrackFactory extends PreJoinPreviewTrackFactory {
  final videoTracks = <MockPreJoinLocalVideoTrack>[];
  final audioTracks = <MockPreJoinLocalAudioTrack>[];

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    final track = MockPreJoinLocalVideoTrack();
    videoTracks.add(track);
    return track;
  }

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    final track = MockPreJoinLocalAudioTrack();
    audioTracks.add(track);
    return track;
  }
}

class _UnavailableTrackFactory extends PreJoinPreviewTrackFactory {
  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) => throw Exception('NotFoundError: no camera is available');

  @override
  Future<LocalAudioTrack?> createAudioTrack() =>
      throw Exception('Audio engine returned error code: -9001');
}

class _SuccessfulSessionController extends SessionController {
  static SessionJoinMedia? receivedMedia;

  @override
  SessionRoomState build(SessionOptions options) => _sessionState;

  @override
  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) async {
    receivedMedia = joinMedia;
    return SessionJoinResult.success;
  }
}

class _RetryableSessionController extends SessionController {
  static int resets = 0;
  static Completer<void>? resetStarted;
  static Completer<void>? resetGate;

  @override
  SessionRoomState build(SessionOptions options) => _sessionState;

  @override
  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) async =>
      SessionJoinResult.retryableFailure;

  @override
  Future<void> resetAfterFailedJoin() async {
    resets++;
    resetStarted?.complete();
    await resetGate?.future;
  }
}

ProviderContainer _container({
  required PreJoinPreviewTrackFactory factory,
  required JoinResponse response,
  required SessionController Function() sessionController,
  bool requireUsableMedia = false,
}) {
  return ProviderContainer(
      overrides: [
        preJoinPreviewTrackFactoryProvider.overrideWithValue(factory),
        preJoinRequiresUsableMediaProvider.overrideWithValue(
          requireUsableMedia,
        ),
        sessionTokenProvider(_slug).overrideWith((_) async => response),
        sessionProvider(_slug).overrideWith((_) async => _event()),
        sessionControllerProvider(_options).overrideWith(sessionController),
      ],
    )
    ..listen(
      preJoinMediaControllerProvider(_slug),
      (_, _) {},
      fireImmediately: true,
    )
    ..listen(
      preJoinFlowControllerProvider(_slug),
      (_, _) {},
      fireImmediately: true,
    );
}

Future<void> _waitForMedia(ProviderContainer container) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (container
        .read(preJoinMediaControllerProvider(_slug))
        .initializationComplete) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Media did not initialize');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupAppConfig);

  test(
    'already-present response requires confirmation before joining',
    () async {
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: true),
        sessionController: _SuccessfulSessionController.new,
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(preJoinFlowControllerProvider(_slug).notifier)
          .requestJoin();

      check(outcome).equals(PreJoinJoinOutcome.confirmationRequired);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).sessionOptions,
      ).isNull();
    },
  );

  test('successful join transfers the initialized preview tracks', () async {
    final factory = _TrackFactory();
    _SuccessfulSessionController.receivedMedia = null;
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);

    final outcome = await container
        .read(preJoinFlowControllerProvider(_slug).notifier)
        .requestJoin();

    check(outcome).equals(PreJoinJoinOutcome.joined);
    check(
      _SuccessfulSessionController.receivedMedia?.cameraTrack,
    ).equals(factory.videoTracks.single);
    check(
      _SuccessfulSessionController.receivedMedia?.microphoneTrack,
    ).equals(factory.audioTracks.single);
  });

  test('permission revocation prevents joining with stale tracks', () async {
    final factory = _TrackFactory();
    _SuccessfulSessionController.receivedMedia = null;
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
      requireUsableMedia: true,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);

    factory.videoTracks.single.mockMediaStreamTrack.onEnded?.call();
    final outcome = await container
        .read(preJoinFlowControllerProvider(_slug).notifier)
        .requestJoin();

    check(outcome).equals(PreJoinJoinOutcome.permissionsDenied);
    check(_SuccessfulSessionController.receivedMedia).isNull();
    check(
      container.read(preJoinFlowControllerProvider(_slug)).phase,
    ).equals(PreJoinFlowPhase.idle);
  });

  test('native join succeeds when no camera or microphone exists', () async {
    _SuccessfulSessionController.receivedMedia = null;
    final container = _container(
      factory: _UnavailableTrackFactory(),
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);

    final mediaState = container.read(preJoinMediaControllerProvider(_slug));
    check(mediaState.camera.phase).equals(PreJoinCapturePhase.unavailable);
    check(mediaState.microphone.phase).equals(PreJoinCapturePhase.unavailable);

    final outcome = await container
        .read(preJoinFlowControllerProvider(_slug).notifier)
        .requestJoin();

    check(outcome).equals(PreJoinJoinOutcome.joined);
    check(_SuccessfulSessionController.receivedMedia?.cameraTrack).isNull();
    check(_SuccessfulSessionController.receivedMedia?.microphoneTrack).isNull();
  });

  test(
    'retryable failure tears down first and opens fresh preview media',
    () async {
      final factory = _TrackFactory();
      _RetryableSessionController.resets = 0;
      final resetStarted = Completer<void>();
      final resetGate = Completer<void>();
      _RetryableSessionController.resetStarted = resetStarted;
      _RetryableSessionController.resetGate = resetGate;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _RetryableSessionController.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);

      final outcomeFuture = container
          .read(preJoinFlowControllerProvider(_slug).notifier)
          .requestJoin();
      await resetStarted.future;

      final detached = container.read(preJoinMediaControllerProvider(_slug));
      check(detached.transferred).equals(true);
      check(detached.camera.track).isNull();
      check(detached.microphone.track).isNull();
      check(factory.videoTracks).length.equals(1);
      check(factory.audioTracks).length.equals(1);

      resetGate.complete();
      final outcome = await outcomeFuture;

      check(outcome).equals(PreJoinJoinOutcome.retryableFailure);
      check(_RetryableSessionController.resets).equals(1);
      check(factory.videoTracks).length.equals(2);
      check(factory.audioTracks).length.equals(2);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      _RetryableSessionController.resetStarted = null;
      _RetryableSessionController.resetGate = null;
    },
  );
}
