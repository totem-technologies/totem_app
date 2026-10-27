import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';
import '../livekit_mocks.dart';

const _slug = 'pre-join-flow-test';

SessionDetailSchema _event({String? keeperSlug}) => SessionDetailSchema(
  slug: _slug,
  title: 'Test session',
  space: MobileSpaceDetailSchema(
    slug: 'test-space',
    title: 'Test Space',
    imageLink: null,
    shortDescription: 'A test space.',
    content: '',
    author: PublicUserSchema(
      slug: Omittable(keeperSlug),
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

class _DelayedUnavailableTrackFactory extends PreJoinPreviewTrackFactory {
  final cameraStarted = Completer<void>();
  final cameraGate = Completer<void>();

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    cameraStarted.complete();
    await cameraGate.future;
    throw Exception('NotFoundError: no camera is available');
  }

  @override
  Future<LocalAudioTrack?> createAudioTrack() async =>
      MockPreJoinLocalAudioTrack();
}

class _SuccessfulSessionController extends SessionController {
  static SessionJoinMedia? receivedMedia;
  static Room? activatedRoom;
  static int activationCalls = 0;

  @override
  SessionRoomState build(SessionOptions options) => _sessionState;

  @override
  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) async {
    receivedMedia = joinMedia;
    return SessionJoinResult.success;
  }

  @override
  Future<SessionJoinResult> activateConnectedRoom({
    required Room room,
    SessionJoinMedia? joinMedia,
    bool Function(String identity)? isAdmitted,
  }) async {
    receivedMedia = joinMedia;
    activatedRoom = room;
    activationCalls++;
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

class _UninitializedSessionController extends _SuccessfulSessionController {
  @override
  void preventAutoDispose() =>
      throw StateError('Session unavailable before media handoff');
}

class _FatalSessionController extends _RetryableSessionController {
  @override
  Future<SessionJoinResult> activateConnectedRoom({
    required Room room,
    SessionJoinMedia? joinMedia,
    bool Function(String identity)? isAdmitted,
  }) async {
    joinMedia?.onBeforeDispose?.call();
    await JoinMediaOwner().retain(joinMedia).dispose();
    await room.disconnect();
    await room.dispose();
    return SessionJoinResult.fatalFailure;
  }
}

class _AdmissionTransport extends LiveKitAdmissionTransport {
  _AdmissionTransport(super.room);

  final eventsController = StreamController<AdmissionEvent>.broadcast(
    sync: true,
  );
  AdmissionRequest? request;
  bool disposed = false;
  bool ended = false;
  bool keepEventsOpenAfterDispose = false;

  @override
  bool get hasEnded => ended;

  void end() {
    ended = true;
    eventsController.add(const AdmissionRoomEnded());
  }

  void fail() => eventsController.add(const AdmissionRoomDisconnected(null));

  @override
  String get localIdentity => 'guest';

  @override
  bool isPresent(String identity) => true;

  @override
  Stream<AdmissionEvent> get events => eventsController.stream;

  @override
  Future<void> send(AdmissionPacket packet) async {
    if (packet is AdmissionRequest) request = packet;
  }

  void decide(bool approved) {
    final packet = request!;
    eventsController.add(
      AdmissionPacketReceived(
        AdmissionDecision(
          id: packet.id,
          senderIdentity: packet.recipientIdentity,
          recipientIdentity: packet.senderIdentity,
          expiresAt: packet.expiresAt,
          approved: approved,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    if (!keepEventsOpenAfterDispose) await eventsController.close();
    disposed = true;
  }
}

class _AdmissionRoom extends Room {
  bool disconnected = false;
  bool disposed = false;

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  Future<bool> dispose() {
    disposed = true;
    return super.dispose();
  }
}

class _AdmissionFlow extends PreJoinFlowController {
  static _AdmissionTransport? transport;
  static int connections = 0;
  static bool failConnection = false;
  static Completer<void>? connectionStarted;
  static Completer<void>? connectionGate;
  static _AdmissionRoom? room;

  @override
  Room createAdmissionRoom() => room = _AdmissionRoom();

  @override
  LiveKitAdmissionTransport createAdmissionTransport(Room room) =>
      transport = _AdmissionTransport(room);

  @override
  Future<void> connectAdmissionRoom(Room room, String token) async {
    connections++;
    connectionStarted?.complete();
    await connectionGate?.future;
    if (failConnection) throw StateError('Admission connection failed');
  }
}

class _AlreadyEndedFlow extends _AdmissionFlow {
  @override
  Future<void> connectAdmissionRoom(Room room, String token) async {
    await super.connectAdmissionRoom(room, token);
    _AdmissionFlow.transport!.ended = true;
  }
}

ProviderContainer _container({
  required PreJoinPreviewTrackFactory factory,
  required JoinResponse response,
  required ValueGetter<SessionController> sessionController,
  Future<JoinResponse> Function()? getToken,
  bool requireUsableMedia = false,
  bool Function()? shouldFailPrecache,
  String? keeperSlug,
  String userSlug = 'guest',
  PreJoinFlowController Function()? flowController,
}) {
  return ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        preJoinPreviewTrackFactoryProvider.overrideWithValue(factory),
        preJoinRequiresUsableMediaProvider.overrideWithValue(
          requireUsableMedia,
        ),
        sessionTokenProvider(
          _slug,
        ).overrideWith((_) => getToken?.call() ?? Future.value(response)),
        sessionProvider(_slug).overrideWith((_) async {
          if (shouldFailPrecache?.call() ?? false) {
            throw StateError('Precache failed');
          }
          return _event(keeperSlug: keeperSlug ?? userSlug);
        }),
        sessionControllerProvider(_options).overrideWith(sessionController),
        if (flowController != null)
          preJoinFlowControllerProvider(_slug).overrideWith(flowController),
        authControllerProvider.overrideWith(
          () => FakeAuthController(
            AuthState.authenticated(
              user: UserSchema(
                email: 'guest@example.com',
                slug: Omittable(userSlug),
                name: const Omittable('Guest'),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime(2024),
              ),
            ),
          ),
        ),
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

  test(
    'terminal token error on Join releases preview and prevents retry',
    () async {
      const terminalError = ApiError<JoinResponse, RoomErrorResponse>(
        statusCode: 409,
        error: RoomErrorResponse(
          code: ErrorCode.roomAlreadyEnded,
          message: 'Session already ended',
        ),
      );
      var tokenCalls = 0;
      final factory = _TrackFactory();
      _SuccessfulSessionController.receivedMedia = null;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        getToken: () async {
          tokenCalls++;
          throw terminalError;
        },
        sessionController: _SuccessfulSessionController.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);

      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(
        await flow.requestJoin(),
      ).equals(PreJoinJoinOutcome.retryableFailure);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error,
      ).equals(terminalError);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      verify(factory.videoTracks.single.stop).called(1);
      verify(factory.videoTracks.single.dispose).called(1);
      verify(factory.audioTracks.single.stop).called(1);
      verify(factory.audioTracks.single.dispose).called(1);
      check(_SuccessfulSessionController.receivedMedia).isNull();
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.ignored);
      check(tokenCalls).equals(1);
    },
  );

  test(
    'approval hands the connected admission room to the session without recapturing media',
    () async {
      final factory = _TrackFactory();
      var tokenRequests = 0;
      _AdmissionFlow.connections = 0;
      _AdmissionFlow.failConnection = false;
      _AdmissionFlow.transport = null;
      _SuccessfulSessionController.receivedMedia = null;
      _SuccessfulSessionController.activatedRoom = null;
      _SuccessfulSessionController.activationCalls = 0;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        getToken: () async {
          tokenRequests++;
          return const JoinResponse(token: 'token', isAlreadyPresent: false);
        },
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);

      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.pending);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.pending);
      check(_AdmissionFlow.transport!.request!.displayName).equals('Guest');
      check(
        _AdmissionFlow.transport!.request!.recipientIdentity,
      ).equals('keeper');
      check(_AdmissionFlow.connections).equals(1);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.ignored);
      check(_AdmissionFlow.connections).equals(1);
      check(_SuccessfulSessionController.receivedMedia).isNull();
      check(
        container.read(preJoinMediaControllerProvider(_slug)).transferred,
      ).equals(false);

      final room = _AdmissionFlow.room!;
      _AdmissionFlow.transport!.decide(true);
      await pumpEventQueue();
      check(_AdmissionFlow.connections).equals(1);
      check(tokenRequests).equals(1);
      check(_SuccessfulSessionController.activationCalls).equals(1);
      check(
        identical(_SuccessfulSessionController.activatedRoom, room),
      ).isTrue();
      check(room.disconnected).isFalse();
      check(room.disposed).isFalse();
      check(factory.videoTracks).length.equals(1);
      check(factory.audioTracks).length.equals(1);
      check(
        _SuccessfulSessionController.receivedMedia?.cameraTrack,
      ).equals(factory.videoTracks.single);
      check(
        _SuccessfulSessionController.receivedMedia?.microphoneTrack,
      ).equals(factory.audioTracks.single);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.joined);
    },
  );

  test(
    'decline releases preview after room teardown and does not allow retry',
    () async {
      final factory = _TrackFactory();
      _AdmissionFlow.failConnection = false;
      _SuccessfulSessionController.receivedMedia = null;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final declinedTransport = _AdmissionFlow.transport!;
      var roomClosedBeforePreviewStopped = false;
      when(factory.videoTracks.single.stop).thenAnswer((_) async {
        roomClosedBeforePreviewStopped = declinedTransport.disposed;
        return true;
      });
      declinedTransport.decide(false);
      await pumpEventQueue();
      check(declinedTransport.disposed).equals(true);
      check(roomClosedBeforePreviewStopped).equals(true);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.denied);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      check(_SuccessfulSessionController.receivedMedia).isNull();
      verify(factory.videoTracks.single.stop).called(1);
      verify(factory.videoTracks.single.dispose).called(1);
      verify(factory.audioTracks.single.stop).called(1);
      verify(factory.audioTracks.single.dispose).called(1);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.ignored);
      check(_SuccessfulSessionController.receivedMedia).isNull();
    },
  );

  test('already-ended room never sends an admission request', () async {
    final factory = _TrackFactory();
    _AdmissionFlow.failConnection = false;
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
      keeperSlug: 'keeper',
      flowController: _AlreadyEndedFlow.new,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);
    final flow = container.read(preJoinFlowControllerProvider(_slug).notifier);
    check(await flow.requestJoin()).equals(PreJoinJoinOutcome.ignored);
    check(_AdmissionFlow.transport!.request).isNull();
    check(_AdmissionFlow.room!.disposed).equals(true);
    check(
      container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
    ).equals(AdmissionStatus.ended);
    verify(factory.videoTracks.single.dispose).called(1);
    verify(factory.audioTracks.single.dispose).called(1);
  });

  test(
    'room ended while waiting releases preview and prevents another join',
    () async {
      final factory = _TrackFactory();
      _AdmissionFlow.failConnection = false;
      _SuccessfulSessionController.receivedMedia = null;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final transport = _AdmissionFlow.transport!..end();
      await pumpEventQueue();
      check(transport.disposed).equals(true);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.ended);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      verify(factory.videoTracks.single.stop).called(1);
      verify(factory.videoTracks.single.dispose).called(1);
      verify(factory.audioTracks.single.stop).called(1);
      verify(factory.audioTracks.single.dispose).called(1);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.ignored);
      check(_SuccessfulSessionController.receivedMedia).isNull();
    },
  );

  test(
    'disconnect leaves preview retryable and old events cannot end the retry',
    () async {
      final factory = _TrackFactory();
      _AdmissionFlow.failConnection = false;
      _SuccessfulSessionController.receivedMedia = null;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final first = _AdmissionFlow.transport!
        ..keepEventsOpenAfterDispose = true;
      addTearDown(first.eventsController.close);
      first.fail();
      await pumpEventQueue();
      check(first.disposed).equals(true);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.failed);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error.toString(),
      ).contains('try again');
      check(
        container.read(preJoinMediaControllerProvider(_slug)).transferred,
      ).equals(false);
      verifyNever(factory.videoTracks.single.stop);
      verifyNever(factory.audioTracks.single.stop);

      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final second = _AdmissionFlow.transport!;
      check(identical(first, second)).equals(false);
      first.end();
      await pumpEventQueue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.pending);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.pending);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error,
      ).isNull();
      check(factory.videoTracks).length.equals(1);
      check(factory.audioTracks).length.equals(1);
      check(_SuccessfulSessionController.receivedMedia).isNull();
      await flow.cancelAdmission();
    },
  );

  test(
    'cancelled admission disposes the connected room without joining',
    () async {
      _AdmissionFlow.failConnection = false;
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final transport = _AdmissionFlow.transport!;
      final room = _AdmissionFlow.room!;
      await flow.cancelAdmission();
      check(transport.disposed).equals(true);
      check(room.disconnected).isTrue();
      check(room.disposed).isTrue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.cancelled);
      check(_SuccessfulSessionController.receivedMedia).isNull();
    },
  );

  test(
    'fatal approval join never reports joined and releases its media',
    () async {
      final factory = _TrackFactory();
      _AdmissionFlow.failConnection = false;
      _RetryableSessionController.resets = 0;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _FatalSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      _AdmissionFlow.transport!.decide(true);
      await pumpEventQueue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error,
      ).isA<StateError>();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).sessionOptions,
      ).isNull();
      check(_RetryableSessionController.resets).equals(1);
      check(_AdmissionFlow.room!.disconnected).isTrue();
      check(_AdmissionFlow.room!.disposed).isTrue();
      verify(factory.videoTracks.first.dispose).called(1);
      check(factory.videoTracks).length.equals(2);
    },
  );

  test(
    'teardown during connection setup disposes the admission room',
    () async {
      _AdmissionFlow.failConnection = false;
      final started = Completer<void>();
      final gate = Completer<void>();
      _AdmissionFlow.connectionStarted = started;
      _AdmissionFlow.connectionGate = gate;
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(() {
        _AdmissionFlow.connectionStarted = null;
        _AdmissionFlow.connectionGate = null;
        container.dispose();
      });
      final attempt = container
          .read(preJoinFlowControllerProvider(_slug).notifier)
          .requestJoin();
      await started.future;
      final room = _AdmissionFlow.room!;
      container.dispose();
      gate.complete();
      check(await attempt).equals(PreJoinJoinOutcome.ignored);
      await pumpEventQueue();
      check(room.disposed).equals(true);
      check(_SuccessfulSessionController.receivedMedia).isNull();
    },
  );

  test(
    'admission connection error is visible and retry can request again',
    () async {
      _AdmissionFlow.failConnection = true;
      _SuccessfulSessionController.receivedMedia = null;
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(() {
        _AdmissionFlow.failConnection = false;
        container.dispose();
      });
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(
        await flow.requestJoin(),
      ).equals(PreJoinJoinOutcome.retryableFailure);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error,
      ).isA<StateError>();
      check(_AdmissionFlow.room!.disposed).equals(true);
      check(_SuccessfulSessionController.receivedMedia).isNull();

      _AdmissionFlow.failConnection = false;
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error,
      ).isNull();
      final transport = _AdmissionFlow.transport!;
      container.dispose();
      await pumpEventQueue();
      check(transport.disposed).equals(true);
    },
  );

  test('keeper joins directly without an admission connection', () async {
    _AdmissionFlow.connections = 0;
    _AdmissionFlow.failConnection = false;
    final container = _container(
      factory: _TrackFactory(),
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
      keeperSlug: 'keeper',
      userSlug: 'keeper',
      flowController: _AdmissionFlow.new,
    );
    addTearDown(container.dispose);
    final outcome = await container
        .read(preJoinFlowControllerProvider(_slug).notifier)
        .requestJoin();
    check(outcome).equals(PreJoinJoinOutcome.joined);
    check(_AdmissionFlow.connections).equals(0);
  });

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

  test(
    'failed session creation disposes unclaimed tracks before recapture',
    () async {
      final factory = _TrackFactory();
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _UninitializedSessionController.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      final outcome = await container
          .read(preJoinFlowControllerProvider(_slug).notifier)
          .requestJoin();
      check(outcome).equals(PreJoinJoinOutcome.retryableFailure);
      verify(factory.videoTracks.first.stop).called(1);
      verify(factory.videoTracks.first.dispose).called(1);
      verify(factory.audioTracks.first.stop).called(1);
      verify(factory.audioTracks.first.dispose).called(1);
      check(factory.videoTracks).length.equals(2);
      check(factory.audioTracks).length.equals(2);
      check(
        container.read(preJoinMediaControllerProvider(_slug)).transferred,
      ).equals(false);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
    },
  );

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
    'joining uses the settled camera preference when initial capture fails',
    () async {
      final factory = _DelayedUnavailableTrackFactory();
      _SuccessfulSessionController.receivedMedia = null;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
      );
      addTearDown(container.dispose);

      final join = container
          .read(preJoinFlowControllerProvider(_slug).notifier)
          .requestJoin();
      await factory.cameraStarted.future;

      check(
        container.read(preJoinFlowControllerProvider(_slug)).sessionOptions,
      ).isNull();

      factory.cameraGate.complete();
      check(await join).equals(PreJoinJoinOutcome.joined);
      check(
        container
            .read(preJoinFlowControllerProvider(_slug))
            .sessionOptions
            ?.cameraEnabled,
      ).equals(false);
      check(_SuccessfulSessionController.receivedMedia?.cameraTrack).isNull();
    },
  );

  test('failed precache leaves preview media available for a retry', () async {
    var failPrecache = true;
    final factory = _TrackFactory();
    _SuccessfulSessionController.receivedMedia = null;
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
      shouldFailPrecache: () => failPrecache,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);

    final flow = container.read(preJoinFlowControllerProvider(_slug).notifier);
    check(await flow.requestJoin()).equals(PreJoinJoinOutcome.retryableFailure);
    check(
      container.read(preJoinMediaControllerProvider(_slug)).transferred,
    ).equals(false);

    failPrecache = false;
    container.invalidate(sessionProvider(_slug));
    check(await flow.requestJoin()).equals(PreJoinJoinOutcome.joined);
    check(_SuccessfulSessionController.receivedMedia?.cameraTrack).isNotNull();
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
