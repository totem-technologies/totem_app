import 'dart:async';

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
  eventSlug: _slug,
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
}) {
  return ProviderContainer(
      overrides: [
        preJoinPreviewTrackFactoryProvider.overrideWithValue(factory),
        sessionTokenProvider(_slug).overrideWith((_) async => response),
        eventProvider(_slug).overrideWith((_) async => _event()),
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

      expect(outcome, PreJoinJoinOutcome.confirmationRequired);
      expect(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
        PreJoinFlowPhase.idle,
      );
      expect(
        container.read(preJoinFlowControllerProvider(_slug)).sessionOptions,
        isNull,
      );
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

    expect(outcome, PreJoinJoinOutcome.joined);
    expect(
      _SuccessfulSessionController.receivedMedia?.cameraTrack,
      factory.videoTracks.single,
    );
    expect(
      _SuccessfulSessionController.receivedMedia?.microphoneTrack,
      factory.audioTracks.single,
    );
  });

  test('permission revocation prevents joining with stale tracks', () async {
    final factory = _TrackFactory();
    _SuccessfulSessionController.receivedMedia = null;
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);

    factory.videoTracks.single.mockMediaStreamTrack.onEnded?.call();
    final outcome = await container
        .read(preJoinFlowControllerProvider(_slug).notifier)
        .requestJoin();

    expect(outcome, PreJoinJoinOutcome.permissionsDenied);
    expect(_SuccessfulSessionController.receivedMedia, isNull);
    expect(
      container.read(preJoinFlowControllerProvider(_slug)).phase,
      PreJoinFlowPhase.idle,
    );
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

      final detached = container.read(
        preJoinMediaControllerProvider(_slug),
      );
      expect(detached.transferred, isTrue);
      expect(detached.camera.track, isNull);
      expect(detached.microphone.track, isNull);
      expect(factory.videoTracks, hasLength(1));
      expect(factory.audioTracks, hasLength(1));

      resetGate.complete();
      final outcome = await outcomeFuture;

      expect(outcome, PreJoinJoinOutcome.retryableFailure);
      expect(_RetryableSessionController.resets, 1);
      expect(factory.videoTracks, hasLength(2));
      expect(factory.audioTracks, hasLength(2));
      expect(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
        PreJoinFlowPhase.idle,
      );
      _RetryableSessionController.resetStarted = null;
      _RetryableSessionController.resetGate = null;
    },
  );
}
