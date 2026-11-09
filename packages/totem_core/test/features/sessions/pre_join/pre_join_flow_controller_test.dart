import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:livekit_client/livekit_client.dart'
    as livekit
    show ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';
import '../../permissions/fake_media_permission_adapter.dart';
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

class _DelayedTrackFactory extends _TrackFactory {
  final cameraStarted = Completer<void>();
  final cameraGate = Completer<void>();

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    cameraStarted.complete();
    await cameraGate.future;
    return super.createVideoTrack(cameraOptions);
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
  static int joinCalls = 0;

  @override
  SessionRoomState build(SessionOptions options) => _sessionState;

  @override
  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) async {
    joinCalls++;
    receivedMedia = joinMedia;
    return SessionJoinResult.success;
  }

  @override
  Future<SessionJoinResult> activateConnectedRoom({
    required Room room,
    SessionJoinMedia? joinMedia,
  }) async {
    receivedMedia = joinMedia;
    activatedRoom = room;
    activationCalls++;
    return SessionJoinResult.success;
  }
}

class _PendingReceiptMessagingController extends SessionMessagingController {
  final receiptGate = Completer<void>();
  AdmissionRequest? receivedRequest;

  @override
  Future<void> sendAdmissionJoined(AdmissionRequest request) {
    receivedRequest = request;
    return receiptGate.future;
  }
}

class _PendingReceiptSessionController extends _SuccessfulSessionController {
  static _PendingReceiptMessagingController? receiptMessaging;

  @override
  SessionMessagingController get messaging => receiptMessaging!;
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

class _FailureReceiptMessaging extends SessionMessagingController {
  final requests = <AdmissionRequest>[];
  final joinedRequests = <AdmissionRequest>[];
  Completer<void>? finished;
  Completer<void>? gate;

  @override
  Future<void> sendAdmissionJoined(AdmissionRequest request) async {
    joinedRequests.add(request);
    finished?.complete();
  }

  @override
  Future<void> sendAdmissionJoinFailed(AdmissionRequest request) {
    requests.add(request);
    _FailureReceiptSession.events.add('failure receipt');
    return gate?.future ?? Future<void>.value();
  }
}

class _FailureReceiptSession extends _RetryableSessionController {
  static late _FailureReceiptMessaging receiptMessaging;
  static SessionJoinResult result = SessionJoinResult.retryableFailure;
  static bool throwActivation = false;
  static bool throwReset = false;
  static final events = <String>[];
  Room? adoptedRoom;
  @override
  Room? get room => adoptedRoom;
  @override
  SessionMessagingController get messaging => receiptMessaging;
  @override
  Future<SessionJoinResult> activateConnectedRoom({
    required Room room,
    SessionJoinMedia? joinMedia,
  }) async {
    adoptedRoom = room;
    if (throwActivation) throw StateError('activation failed');
    return result;
  }

  @override
  Future<void> resetAfterFailedJoin() async {
    events.add('reset');
    if (throwReset) throw StateError('reset failed');
  }
}

class _PendingActivationSession extends _FailureReceiptSession {
  static late Completer<void> started;
  static late Completer<SessionJoinResult> gate;

  @override
  Future<SessionJoinResult> activateConnectedRoom({
    required Room room,
    SessionJoinMedia? joinMedia,
  }) {
    adoptedRoom = room;
    started.complete();
    return gate.future;
  }

  @override
  Future<void> resetAfterFailedJoin() async {
    await super.resetAfterFailedJoin();
    _FailureReceiptSession.receiptMessaging.finished?.complete();
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
  bool endWhenRequestSent = false;
  bool keepEventsOpenAfterDispose = false;
  Completer<void>? cancelSendGate;
  int cancelSends = 0;
  void Function(AdmissionPacket)? onSend;

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
    onSend?.call(packet);
    if (packet is AdmissionRequest) {
      request = packet;
      if (endWhenRequestSent) end();
    } else if (packet is AdmissionCancel) {
      cancelSends++;
      await cancelSendGate?.future;
    }
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
  bool throwOnDisconnect = false;
  bool throwOnDispose = false;

  @override
  Future<void> disconnect() async {
    disconnected = true;
    if (throwOnDisconnect) throw StateError('Admission room disconnect failed');
  }

  @override
  Future<bool> dispose() async {
    disposed = true;
    if (throwOnDispose) throw StateError('Admission room dispose failed');
    return super.dispose();
  }
}

class _ObservedSessionController extends SessionController {
  static final instances = <_ObservedSessionController>[];
  bool disposed = false;

  @override
  SessionRoomState build(SessionOptions options) {
    instances.add(this);
    ref.onDispose(() => disposed = true);
    return super.build(options);
  }
}

class _ConnectedAdmissionRoom extends _AdmissionRoom {
  final participant = MockLocalParticipant('guest');

  @override
  livekit.ConnectionState get connectionState =>
      livekit.ConnectionState.connected;

  @override
  LocalParticipant get localParticipant => participant;
}

class _RealSessionAdmissionFlow extends _AdmissionFlow {
  @override
  Room createAdmissionRoom() => _AdmissionFlow.room = _ConnectedAdmissionRoom();
}

class _AdmissionFlow extends PreJoinFlowController {
  static _AdmissionTransport? transport;
  static void Function(_AdmissionTransport)? onTransportCreated;
  static int connections = 0;
  static bool failConnection = false;
  static bool endWhenRequestSent = false;
  static Completer<void>? connectionStarted;
  static Completer<void>? connectionGate;
  static _AdmissionRoom? room;

  @override
  Room createAdmissionRoom() => room = _AdmissionRoom();

  @override
  LiveKitAdmissionTransport createAdmissionTransport(Room room) {
    final created = _AdmissionTransport(room)
      ..endWhenRequestSent = endWhenRequestSent;
    transport = created;
    onTransportCreated?.call(created);
    return created;
  }

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

  SessionOptions sessionOptions = _options,
  bool Function()? shouldFailPrecache,
  String? keeperSlug,
  String userSlug = 'guest',
  PreJoinFlowController Function()? flowController,
  Future<void>? precacheGate,
  bool stableSession = false,
}) {
  return ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        platformInfoProvider.overrideWithValue(
          const WebPlatform(browser: WebBrowser.chrome, os: HostOs.macos),
        ),
        mediaPermissionAdapterProvider.overrideWithValue(
          FakeMediaPermissionAdapter(),
        ),
        preJoinPreviewTrackFactoryProvider.overrideWithValue(factory),

        sessionTokenProvider(
          _slug,
        ).overrideWith((_) => getToken?.call() ?? Future.value(response)),
        if (stableSession) ...[
          sessionProvider(_slug).overrideWithValue(
            AsyncData(_event(keeperSlug: keeperSlug ?? userSlug)),
          ),
          roomStateProvider(
            _slug,
          ).overrideWith((_) async => _sessionState.roomState),
        ] else
          sessionProvider(_slug).overrideWith((_) async {
            await precacheGate;
            if (shouldFailPrecache?.call() ?? false) {
              throw StateError('Precache failed');
            }
            return _event(keeperSlug: keeperSlug ?? userSlug);
          }),
        sessionControllerProvider(
          sessionOptions,
        ).overrideWith(sessionController),
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
      check(
        container.read(preJoinFlowControllerProvider(_slug)).keeperAvailability,
      ).equals(AdmissionKeeperAvailability.checking);
      _AdmissionFlow.transport!.eventsController.add(
        const AdmissionPresenceChanged('keeper', false),
      );
      await pumpEventQueue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).keeperAvailability,
      ).equals(AdmissionKeeperAvailability.absent);
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
    'microphone lost after approval reports failure before room closes',
    () async {
      final factory = _TrackFactory();
      _AdmissionFlow.failConnection = false;
      _SuccessfulSessionController.receivedMedia = null;
      _SuccessfulSessionController.activationCalls = 0;
      _SuccessfulSessionController.joinCalls = 0;
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
      final transport = _AdmissionFlow.transport!;
      final room = _AdmissionFlow.room!;
      final request = transport.request!;
      final receipts = <AdmissionPacket>[];
      var connectedAtSend = false;
      _AdmissionFlow.onTransportCreated = (receiptTransport) {
        receiptTransport.onSend = (packet) {
          if (packet is AdmissionJoinFailed) {
            receipts.add(packet);
            connectedAtSend =
                !receiptTransport.disposed &&
                !room.disconnected &&
                !room.disposed;
          }
        };
      };
      addTearDown(() => _AdmissionFlow.onTransportCreated = null);

      transport.decide(true);
      factory.audioTracks.single.mockMediaStreamTrack.onEnded?.call();
      await pumpEventQueue();

      check(_SuccessfulSessionController.activationCalls).equals(0);
      check(_SuccessfulSessionController.joinCalls).equals(0);
      check(_SuccessfulSessionController.receivedMedia).isNull();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      check(room.disconnected).isTrue();
      check(room.disposed).isTrue();
      check(transport.disposed).isTrue();
      check(receipts).length.equals(1);
      check(receipts.single.id).equals(request.id);
      check(receipts.single.senderIdentity).equals('guest');
      check(receipts.single.recipientIdentity).equals('keeper');
      check(connectedAtSend).isTrue();
    },
  );

  test(
    'a pending receipt send does not hold an activated participant on pre-join',
    () async {
      final messaging = _PendingReceiptMessagingController();
      _PendingReceiptSessionController.receiptMessaging = messaging;
      addTearDown(
        () => _PendingReceiptSessionController.receiptMessaging = null,
      );
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _PendingReceiptSessionController.new,
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
        messaging.receivedRequest?.id,
      ).equals(_AdmissionFlow.transport!.request!.id);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.joined);
      messaging.receiptGate.complete();
    },
  );

  test(
    'cancellation during approved room activation rejects late success',
    () async {
      final messaging = _FailureReceiptMessaging()
        ..finished = Completer<void>();
      _FailureReceiptSession.receiptMessaging = messaging;
      _FailureReceiptSession.throwReset = false;
      _FailureReceiptSession.events.clear();
      _PendingActivationSession.started = Completer<void>();
      _PendingActivationSession.gate = Completer<SessionJoinResult>();
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _PendingActivationSession.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      final phases = <PreJoinFlowPhase>[];
      container.listen(preJoinFlowControllerProvider(_slug), (_, next) {
        phases.add(next.phase);
      });
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final transport = _AdmissionFlow.transport!;
      final request = transport.request!;
      transport.decide(true);
      await _PendingActivationSession.started.future;

      await flow.cancelAdmission();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.cancelled);
      _PendingActivationSession.gate.complete(SessionJoinResult.success);
      await messaging.finished!.future;
      await pumpEventQueue();

      check(phases.contains(PreJoinFlowPhase.joined)).isFalse();
      check(messaging.joinedRequests).isEmpty();
      check(messaging.requests).length.equals(1);
      check(messaging.requests.single.id).equals(request.id);
      check(
        _FailureReceiptSession.events,
      ).deepEquals(['failure receipt', 'reset']);
      check(transport.disposed).isTrue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.cancelled);
    },
  );

  for (final scenario in [
    'retryable',
    'fatal',
    'thrown',
    'reset throws',
    'stalled',
  ]) {
    test('approval $scenario failure reports before reset', () async {
      final clock = FakeAsync();
      await runZoned(
        () async {
          final messaging = _FailureReceiptMessaging();
          if (scenario == 'stalled') messaging.gate = Completer<void>();
          _FailureReceiptSession.receiptMessaging = messaging;
          _FailureReceiptSession.result = scenario == 'fatal'
              ? SessionJoinResult.fatalFailure
              : SessionJoinResult.retryableFailure;
          _FailureReceiptSession.throwActivation = scenario == 'thrown';
          _FailureReceiptSession.throwReset = scenario == 'reset throws';
          _FailureReceiptSession.events.clear();
          var tokenRequests = 0;
          _AdmissionFlow.connections = 0;
          final container = _container(
            factory: _TrackFactory(),
            response: const JoinResponse(
              token: 'token',
              isAlreadyPresent: false,
            ),
            getToken: () async {
              tokenRequests++;
              return const JoinResponse(
                token: 'token',
                isAlreadyPresent: false,
              );
            },
            sessionController: _FailureReceiptSession.new,
            keeperSlug: 'keeper',
            flowController: _AdmissionFlow.new,
          );
          addTearDown(container.dispose);
          await _waitForMedia(container);
          final flow = container.read(
            preJoinFlowControllerProvider(_slug).notifier,
          );
          check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
          final request = _AdmissionFlow.transport!.request!;
          _AdmissionFlow.transport!.decide(true);
          await pumpEventQueue();
          check(messaging.requests).length.equals(1);
          check(messaging.requests.single.id).equals(request.id);
          check(messaging.requests.single.recipientIdentity).equals('keeper');
          if (scenario == 'stalled') {
            check(
              _FailureReceiptSession.events,
            ).deepEquals(['failure receipt']);
            clock.elapse(const Duration(milliseconds: 501));
          }
          await pumpEventQueue();
          check(
            _FailureReceiptSession.events.take(2).toList(),
          ).deepEquals(['failure receipt', 'reset']);
          check(
            container.read(preJoinFlowControllerProvider(_slug)).phase ==
                PreJoinFlowPhase.joined,
          ).isFalse();
          check(messaging.requests).length.equals(1);
          messaging.gate?.complete();
          check(tokenRequests).equals(1);
          check(_AdmissionFlow.connections).equals(1);
        },
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            if (duration == const Duration(milliseconds: 500)) {
              return clock.run((_) => Timer(duration, callback));
            }
            return parent.createTimer(zone, duration, callback);
          },
        ),
      );
    });
  }

  test(
    'replacing an existing session joins after immediate approval',
    () async {
      const options = SessionOptions(
        sessionSlug: _slug,
        token: 'token',
        cameraEnabled: false,
        microphoneEnabled: false,
        speakerEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
      );
      _ObservedSessionController.instances.clear();
      _AdmissionFlow.failConnection = false;
      _AdmissionFlow.endWhenRequestSent = false;
      _AdmissionFlow.onTransportCreated = (transport) {
        final room = transport.room as _ConnectedAdmissionRoom;
        when(room.participant.unpublishAllTracks).thenAnswer((_) async {});
        when(
          () => room.participant.setMicrophoneEnabled(
            false,
            audioCaptureOptions: any(named: 'audioCaptureOptions'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => room.participant.publishData(
            any(),
            reliable: any(named: 'reliable'),
            topic: any(named: 'topic'),
            destinationIdentities: any(named: 'destinationIdentities'),
          ),
        ).thenAnswer((_) async {});
        transport.onSend = (packet) {
          if (packet is AdmissionRequest) {
            transport.eventsController.add(
              AdmissionPacketReceived(
                AdmissionDecision(
                  id: packet.id,
                  senderIdentity: packet.recipientIdentity,
                  recipientIdentity: packet.senderIdentity,
                  expiresAt: packet.expiresAt,
                  approved: true,
                ),
              ),
            );
          }
        };
      };
      addTearDown(() => _AdmissionFlow.onTransportCreated = null);
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: true),
        sessionController: _ObservedSessionController.new,
        sessionOptions: options,
        keeperSlug: 'keeper',
        flowController: _RealSessionAdmissionFlow.new,
        stableSession: true,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      await container.read(sessionProvider(_slug).future);
      final media = container.read(
        preJoinMediaControllerProvider(_slug).notifier,
      );
      await media.turnOff(MediaKind.camera);
      await media.turnOff(MediaKind.microphone);
      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      check(
        await flow.requestJoin(),
      ).equals(PreJoinJoinOutcome.confirmationRequired);
      await flow.requestJoin(replaceExistingSession: true);
      await pumpEventQueue();
      final room = _AdmissionFlow.room! as _ConnectedAdmissionRoom;
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.joined);
      check(_ObservedSessionController.instances.length).equals(1);
      final session = _ObservedSessionController.instances.single;
      check(identical(session.room, room)).isTrue();
      check(
        session.state.connectionState,
      ).equals(RoomConnectionState.connected);
      check(room.disposed).isFalse();
      container.invalidate(preJoinFlowControllerProvider(_slug));
      await pumpEventQueue();
      check(session.disposed).isTrue();
      check(room.disposed).isTrue();
    },
  );

  for (final (camera, microphone) in [
    (false, false),
    (false, true),
    (true, false),
    (true, true),
  ]) {
    test(
      'approved session stays connected until pre-join flow is disposed '
      '(camera: $camera, microphone: $microphone)',
      () async {
        final options = SessionOptions(
          sessionSlug: _slug,
          token: 'token',
          cameraEnabled: camera,
          microphoneEnabled: microphone,
          speakerEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
        );
        _ObservedSessionController.instances.clear();
        _AdmissionFlow.failConnection = false;
        _AdmissionFlow.endWhenRequestSent = false;
        _AdmissionFlow.onTransportCreated = null;
        final factory = _TrackFactory();
        final container = _container(
          factory: factory,
          response: const JoinResponse(token: 'token', isAlreadyPresent: false),
          sessionController: _ObservedSessionController.new,
          sessionOptions: options,
          keeperSlug: 'keeper',
          flowController: _RealSessionAdmissionFlow.new,
          stableSession: true,
        );
        addTearDown(container.dispose);
        await _waitForMedia(container);
        await container.read(sessionProvider(_slug).future);
        final media = container.read(
          preJoinMediaControllerProvider(_slug).notifier,
        );
        if (!camera) await media.turnOff(MediaKind.camera);
        if (!microphone) await media.turnOff(MediaKind.microphone);
        final flow = container.read(
          preJoinFlowControllerProvider(_slug).notifier,
        );
        check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
        final room = _AdmissionFlow.room! as _ConnectedAdmissionRoom;
        if (camera) {
          when(
            () => room.participant.publishVideoTrack(
              factory.videoTracks.last,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          ).thenAnswer((_) async => MockLocalTrackPublication());
        }
        if (microphone) {
          when(
            () => room.participant.publishAudioTrack(factory.audioTracks.last),
          ).thenAnswer((_) async => MockLocalAudioTrackPublication());
        }
        when(room.participant.unpublishAllTracks).thenAnswer((_) async {});
        when(
          () => room.participant.setMicrophoneEnabled(
            false,
            audioCaptureOptions: any(named: 'audioCaptureOptions'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => room.participant.publishData(
            any(),
            reliable: any(named: 'reliable'),
            topic: any(named: 'topic'),
            destinationIdentities: any(named: 'destinationIdentities'),
          ),
        ).thenAnswer((_) async {});
        _AdmissionFlow.transport!.decide(true);
        await pumpEventQueue();
        final flowState = container.read(preJoinFlowControllerProvider(_slug));
        check(flowState.phase).equals(PreJoinFlowPhase.joined);
        check(flowState.sessionOptions).equals(options);
        check(_ObservedSessionController.instances.length).equals(1);
        final session = _ObservedSessionController.instances.single;
        check(session.disposed).isFalse();
        check(identical(session.room, room)).isTrue();
        check(
          session.state.connectionState,
        ).equals(RoomConnectionState.connected);
        check(room.disposed).isFalse();

        container.invalidate(preJoinFlowControllerProvider(_slug));
        await pumpEventQueue();
        check(session.disposed).isTrue();
        check(room.disposed).isTrue();
      },
    );
  }

  test('camera-off approval enters the session with the same room', () async {
    const cameraOffOptions = SessionOptions(
      sessionSlug: _slug,
      token: 'token',
      cameraEnabled: false,
      microphoneEnabled: true,
      speakerEnabled: true,
      cameraOptions: SessionController.defaultCameraCaptureOptions,
    );
    final factory = _TrackFactory();
    _SuccessfulSessionController.activationCalls = 0;
    _SuccessfulSessionController.receivedMedia = null;
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
      sessionOptions: cameraOffOptions,
      keeperSlug: 'keeper',
      flowController: _AdmissionFlow.new,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);
    await container
        .read(preJoinMediaControllerProvider(_slug).notifier)
        .turnOff(MediaKind.camera);

    final flow = container.read(preJoinFlowControllerProvider(_slug).notifier);
    check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
    _AdmissionFlow.transport!.decide(true);
    await pumpEventQueue();

    check(_SuccessfulSessionController.activationCalls).equals(1);
    check(_SuccessfulSessionController.receivedMedia?.cameraTrack).isNull();
    check(
      _SuccessfulSessionController.receivedMedia?.microphoneTrack,
    ).equals(factory.audioTracks.single);
    check(
      container.read(preJoinFlowControllerProvider(_slug)).phase,
    ).equals(PreJoinFlowPhase.joined);
  });

  test(
    'first approval waits for in-flight preview capture before activating the room',
    () async {
      final factory = _DelayedTrackFactory();
      _AdmissionFlow.connections = 0;
      _SuccessfulSessionController.activationCalls = 0;
      final container = _container(
        factory: factory,
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(container.dispose);
      await factory.cameraStarted.future;

      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      final joining = flow.requestJoin();
      await pumpEventQueue();
      check(_AdmissionFlow.connections).equals(0);
      factory.cameraGate.complete();
      check(await joining).equals(PreJoinJoinOutcome.pending);
      _AdmissionFlow.transport!.decide(true);
      await pumpEventQueue();
      check(_SuccessfulSessionController.activationCalls).equals(1);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.joined);
      check(factory.videoTracks).length.equals(1);
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
    'room cleanup errors do not override a denied admission outcome',
    () async {
      final factory = _TrackFactory();
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
      final room = _AdmissionFlow.room!
        ..throwOnDisconnect = true
        ..throwOnDispose = true;
      _AdmissionFlow.transport!.decide(false);
      await pumpEventQueue();

      final state = container.read(preJoinFlowControllerProvider(_slug));
      check(room.disconnected).isTrue();
      check(room.disposed).isTrue();
      check(state.phase).equals(PreJoinFlowPhase.idle);
      check(state.admissionStatus).equals(AdmissionStatus.denied);
      check(state.error).isNull();
      verify(factory.videoTracks.single.dispose).called(1);
      verify(factory.audioTracks.single.dispose).called(1);
    },
  );

  test(
    'a synchronously ended admission publishes one terminal transition',
    () async {
      _AdmissionFlow.endWhenRequestSent = true;
      final container = _container(
        factory: _TrackFactory(),
        response: const JoinResponse(token: 'token', isAlreadyPresent: false),
        sessionController: _SuccessfulSessionController.new,
        keeperSlug: 'keeper',
        flowController: _AdmissionFlow.new,
      );
      addTearDown(() {
        _AdmissionFlow.endWhenRequestSent = false;
        container.dispose();
      });
      await _waitForMedia(container);
      var endedTransitions = 0;
      final subscription = container.listen<PreJoinFlowState>(
        preJoinFlowControllerProvider(_slug),
        (_, next) {
          if (next.admissionStatus == AdmissionStatus.ended) {
            endedTransitions++;
          }
        },
      );
      addTearDown(subscription.close);

      final flow = container.read(
        preJoinFlowControllerProvider(_slug).notifier,
      );
      final joining = flow.requestJoin();
      check(await joining).equals(PreJoinJoinOutcome.ignored);
      await pumpEventQueue();

      check(endedTransitions).equals(1);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.ended);
    },
  );

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
      final cancelSendGate = Completer<void>();
      transport.cancelSendGate = cancelSendGate;
      var cancelled = false;
      final cancellation = flow.cancelAdmission().then((_) => cancelled = true);
      await pumpEventQueue();
      check(cancelled).isTrue();
      check(transport.cancelSends).equals(1);
      check(transport.disposed).equals(true);
      check(room.disconnected).isTrue();
      check(room.disposed).isTrue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.cancelled);
      check(_SuccessfulSessionController.receivedMedia).isNull();
      cancelSendGate.completeError(StateError('send failed after cleanup'));
      await cancellation;
      await pumpEventQueue();
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

  test('X3: a lost camera still joins, without it', () async {
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

    check(outcome).equals(PreJoinJoinOutcome.joined);
    check(_SuccessfulSessionController.receivedMedia?.cameraTrack).isNull();
    check(
      _SuccessfulSessionController.receivedMedia?.microphoneTrack,
    ).equals(factory.audioTracks.single);
  });

  test('W9: a lost microphone prevents joining with stale tracks', () async {
    final factory = _TrackFactory();
    _SuccessfulSessionController.receivedMedia = null;
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);

    factory.audioTracks.single.mockMediaStreamTrack.onEnded?.call();
    final outcome = await container
        .read(preJoinFlowControllerProvider(_slug).notifier)
        .requestJoin();

    check(outcome).equals(PreJoinJoinOutcome.microphoneNeeded);
    check(_SuccessfulSessionController.receivedMedia).isNull();
    check(
      container.read(preJoinFlowControllerProvider(_slug)).phase,
    ).equals(PreJoinFlowPhase.idle);
  });

  test('W9: a microphone lost while the session loads still blocks', () async {
    final factory = _TrackFactory();
    _SuccessfulSessionController.receivedMedia = null;
    final precache = Completer<void>();
    final container = _container(
      factory: factory,
      response: const JoinResponse(token: 'token', isAlreadyPresent: false),
      sessionController: _SuccessfulSessionController.new,
      precacheGate: precache.future,
    );
    addTearDown(container.dispose);
    await _waitForMedia(container);

    final joining = container
        .read(preJoinFlowControllerProvider(_slug).notifier)
        .requestJoin();
    await pumpEventQueue();
    factory.audioTracks.single.mockMediaStreamTrack.onEnded?.call();
    precache.complete();
    final outcome = await joining;

    check(outcome).equals(PreJoinJoinOutcome.microphoneNeeded);
    check(_SuccessfulSessionController.receivedMedia).isNull();
  });

  test('X4: no microphone prevents joining', () async {
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

    check(outcome).equals(PreJoinJoinOutcome.microphoneNeeded);
    check(_SuccessfulSessionController.receivedMedia).isNull();
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
