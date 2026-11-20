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
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';

import 'package:totem_core/features/permissions/platform_info.dart';

import 'package:totem_core/features/sessions/admission/server_participant_admission.dart';

import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/repositories/participant_admission_repository.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';
import '../../permissions/fake_media_permission_adapter.dart';
import '../livekit_mocks.dart';

const _slug = 'pre-join-flow-test';
final _defaultTime = DateTime(2024);

SessionDetailSchema _event({String? keeperSlug, DateTime? start}) =>
    SessionDetailSchema(
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
      start: start ?? _defaultTime,
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
  final started = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions options,
  ) async {
    started.complete();
    await gate.future;
    return await super.createVideoTrack(options);
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
  static Room? activatedRoom;
  static int activationCalls = 0;
  static ServerParticipantAdmission? receivedServerAdmission;
  static Completer<SessionJoinResult>? activationGate;

  @override
  SessionRoomState build(SessionOptions options) => _sessionState;

  @override
  Future<SessionJoinResult> activateConnectedRoom({
    required Room room,
    SessionJoinMedia? joinMedia,
    ServerParticipantAdmission? serverAdmission,
  }) async {
    receivedMedia = joinMedia;
    activatedRoom = room;
    receivedServerAdmission = serverAdmission;
    activationCalls++;
    return await activationGate?.future ?? SessionJoinResult.success;
  }
}

class _ResettableSessionController extends _SuccessfulSessionController {
  int resets = 0;

  @override
  Future<void> resetAfterFailedJoin() async {
    resets++;
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
    return await super.dispose();
  }
}

class _DefaultFlow extends PreJoinFlowController {
  @override
  DateTime now() => _defaultTime;
}

class _AdmissionFlow extends _DefaultFlow {
  static int connections = 0;
  static Completer<void>? connectionStarted;
  static Completer<void>? connectionGate;
  static bool failConnection = false;
  @override
  Room createAdmissionRoom() => _AdmissionRoom();

  @override
  Future<void> connectAdmissionRoom(Room room, String token) async {
    connections++;
    connectionStarted?.complete();
    await connectionGate?.future;
    if (failConnection) throw StateError('connection failed');
  }
}

AdmissionJoinState _serverInitial({bool admitted = false}) =>
    AdmissionJoinState.fromJson({
      'request_id': 'request',
      'attempt_id': 'attempt',
      'status': 'pending',
      'durable_state': 'pending',
      'approval_required': true,
      'expires_at': _defaultTime
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      'permissions': admitted ? 'admitted' : 'waiting',
      'permission_sync': 'pending',
      'revision': 1,
    });

AdmissionMeSnapshot _serverSnapshot(String status, {bool returning = false}) =>
    AdmissionMeSnapshot.fromJson({
      'session_slug': _slug,
      'keeper': 'keeper',
      'room_version': 1,
      'room_status': 'active',
      'approval_required': true,
      'settings_revision': 1,
      'version': status == 'pending' ? 1 : 2,
      'observed_at': _defaultTime.toIso8601String(),
      'admitted_count': 0,
      'activated_count': 0,
      'pending_count': 1,
      'me': {
        'identity': 'guest',
        'user': {
          'profile_avatar_type': 'boring',
          'date_created': _defaultTime.toIso8601String(),
        },
        'admission_state': status == 'approved' || status == 'activated'
            ? 'admitted'
            : 'none',
        'admission_version': 1,
        'request_id': 'request',
        'attempt_id': 'attempt',
        'attempt_version': status == 'pending' ? 1 : 2,
        'status': status,
        'connection_state': 'connected',
        'eligible': true,
        'returning': returning,
        'session_started': returning,
        'late_arrival': false,
        'permission_status': 'applied',
        'permission_revision': 1,
        'applied_permission_revision': 1,
      },
    });

class _ServerRepository implements ParticipantAdmissionRepository {
  AdmissionMeSnapshot current = _serverSnapshot('pending');
  Completer<AdmissionMeSnapshot>? waiting;
  int activations = 0;
  Completer<AdmissionMeSnapshot>? activationWaiting;
  int cancellations = 0;
  int reads = 0;

  @override
  Future<AdmissionMeSnapshot> request({
    required String sessionSlug,
    required String requestId,
    required String attemptId,
    bool connected = false,
  }) async => current;

  @override
  Future<AdmissionMeSnapshot> me({required String sessionSlug}) {
    reads++;
    return waiting?.future ?? Future.value(current);
  }

  @override
  Future<AdmissionMeSnapshot> activated({
    required String sessionSlug,
    required AttemptReceiptInput receipt,
  }) async {
    activations++;
    return await activationWaiting?.future ?? current;
  }

  @override
  Future<AdmissionMeSnapshot> cancel({
    required String sessionSlug,
    required AttemptReceiptInput receipt,
  }) async {
    cancellations++;
    return _serverSnapshot('cancelled');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServerConnection implements ServerAdmissionConnection {
  final events = StreamController<ServerAdmissionConnectionEvent>.broadcast(
    sync: true,
  );
  bool disposed = false;
  @override
  bool isConnected = true;
  @override
  bool hasMediaPermissions = false;
  @override
  String localSid = 'sid';
  @override
  bool isPresent(String identity) => true;
  @override
  Stream<ServerAdmissionConnectionEvent> get admissionEvents => events.stream;
  @override
  Future<void> dispose() {
    disposed = true;
    return events.close();
  }
}

class _ServerFlow extends _AdmissionFlow {
  _ServerFlow(this.repository, this.connection);
  final _ServerRepository repository;
  final _ServerConnection connection;
  ServerParticipantAdmission? admission;
  Room? admissionRoom;

  @override
  ServerParticipantAdmission createServerAdmission(
    Room room,
    AdmissionJoinState initial,
  ) {
    admissionRoom = room;
    return admission = ServerParticipantAdmission(
      repository: repository,
      sessionSlug: _slug,
      initial: initial,
      connection: connection,
      now: () => _defaultTime,
    );
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
  DateTime? sessionStart,
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
            AsyncData(
              _event(keeperSlug: keeperSlug ?? userSlug, start: sessionStart),
            ),
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
            return _event(
              keeperSlug: keeperSlug ?? userSlug,
              start: sessionStart,
            );
          }),
        sessionControllerProvider(
          sessionOptions,
        ).overrideWith(sessionController),
        preJoinFlowControllerProvider(
          _slug,
        ).overrideWith(flowController ?? _DefaultFlow.new),
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

  group('server admission', () {
    for (final admission in [
      const Omittable<AdmissionJoinState?>.absent(),
      const Omittable<AdmissionJoinState?>(null),
      for (final status in ['future_status', 'declined', 'expired'])
        Omittable<AdmissionJoinState?>(
          AdmissionJoinState(
            requestId: 'request-1',
            attemptId: 'attempt-1',
            status: status,
            durableState: 'none',
            approvalRequired: true,
            expiresAt: DateTime(2025),
            permissions: AdmissionJoinStatePermissions.fromJson('waiting'),
            permissionSync: 'pending',
            revision: 1,
          ),
        ),
      Omittable<AdmissionJoinState?>(
        AdmissionJoinState(
          requestId: 'request-1',
          attemptId: 'attempt-1',
          status: 'pending',
          durableState: 'none',
          approvalRequired: true,
          expiresAt: DateTime(2025),
          permissions: AdmissionJoinStatePermissions.fromJson('unsupported'),
          permissionSync: 'pending',
          revision: 1,
        ),
      ),
    ]) {
      test(
        'rejects missing or unsupported admission before connecting',
        () async {
          final flow = _ServerFlow(_ServerRepository(), _ServerConnection());
          _AdmissionFlow.connections = 0;
          final container = _container(
            factory: _TrackFactory(),
            response: JoinResponse(
              token: 'token',
              isAlreadyPresent: false,
              admission: admission,
            ),
            sessionController: _SuccessfulSessionController.new,
            flowController: () => flow,
          );
          addTearDown(container.dispose);
          await _waitForMedia(container);
          check(
            await flow.requestJoin(),
          ).equals(PreJoinJoinOutcome.retryableFailure);
          check(_AdmissionFlow.connections).equals(0);
          check(
            container.read(preJoinFlowControllerProvider(_slug)).error,
          ).isNotNull();
        },
      );
    }

    const serverOptions = SessionOptions(
      sessionSlug: _slug,
      token: 'token',
      cameraEnabled: true,
      microphoneEnabled: true,
      speakerEnabled: true,
      cameraOptions: SessionController.defaultCameraCaptureOptions,
    );

    test(
      'admitted profile stays joining while authorization is confirmed',
      () async {
        final repository = _ServerRepository();
        final connection = _ServerConnection();
        final flow = _ServerFlow(repository, connection);
        _SuccessfulSessionController.activationCalls = 0;
        final container = _container(
          factory: _TrackFactory(),
          response: JoinResponse(
            token: 'token',
            isAlreadyPresent: false,
            admission: Omittable(_serverInitial(admitted: true)),
          ),
          sessionController: _SuccessfulSessionController.new,
          sessionOptions: serverOptions,
          flowController: () => flow,
        );
        addTearDown(() async {
          container.dispose();
          await pumpEventQueue();
          await flow.admission?.dispose();
        });
        await _waitForMedia(container);
        await flow.requestJoin();
        check(
          container.read(preJoinFlowControllerProvider(_slug)).phase,
        ).equals(PreJoinFlowPhase.joining);
        check(_SuccessfulSessionController.activationCalls).equals(0);
        repository.current = _serverSnapshot('approved');
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        await pumpEventQueue();
        check(
          container.read(preJoinFlowControllerProvider(_slug)).phase,
        ).equals(PreJoinFlowPhase.joining);
        check(_SuccessfulSessionController.activationCalls).equals(0);
      },
    );

    test(
      'approval waits for permissions and transfers the connected room and preview once',
      () async {
        final factory = _TrackFactory();
        final repository = _ServerRepository();
        final connection = _ServerConnection();
        final flow = _ServerFlow(repository, connection);
        _AdmissionFlow.connections = 0;
        _SuccessfulSessionController.activationCalls = 0;

        _SuccessfulSessionController.activationGate =
            Completer<SessionJoinResult>();
        final container = _container(
          factory: factory,
          response: JoinResponse(
            token: 'token',
            isAlreadyPresent: false,
            admission: Omittable(_serverInitial()),
          ),
          sessionController: _SuccessfulSessionController.new,
          sessionOptions: serverOptions,
          flowController: () => flow,
        );
        addTearDown(() async {
          container.dispose();
          await flow.admission?.dispose();
          _SuccessfulSessionController.activationGate = null;
        });
        await _waitForMedia(container);
        check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
        repository.current = _serverSnapshot('approved', returning: true);
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        await pumpEventQueue();
        check(
          container.read(preJoinFlowControllerProvider(_slug)).phase,
        ).equals(PreJoinFlowPhase.pending);
        check(_SuccessfulSessionController.activationCalls).equals(0);
        check(repository.activations).equals(0);

        connection.hasMediaPermissions = true;
        connection.events.add(
          ServerAdmissionConnectionEvent.permissionsChanged,
        );
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        await pumpEventQueue();
        check(_SuccessfulSessionController.activationCalls).equals(1);
        check(
          identical(
            _SuccessfulSessionController.activatedRoom,
            flow.admissionRoom,
          ),
        ).isTrue();
        check(
          identical(
            _SuccessfulSessionController.receivedServerAdmission,
            flow.admission,
          ),
        ).isTrue();
        check(
          _SuccessfulSessionController.receivedMedia?.cameraTrack,
        ).equals(factory.videoTracks.single);
        check(
          _SuccessfulSessionController.receivedMedia?.microphoneTrack,
        ).equals(factory.audioTracks.single);
        check(_AdmissionFlow.connections).equals(1);

        check(factory.videoTracks.length).equals(1);
        check(factory.audioTracks.length).equals(1);
        check(repository.activations).equals(0);
        _SuccessfulSessionController.activationGate!.complete(
          SessionJoinResult.success,
        );
        await pumpEventQueue();
        check(repository.activations).equals(1);
        final state = container.read(preJoinFlowControllerProvider(_slug));
        check(state.phase).equals(PreJoinFlowPhase.joined);
        check(state.isReturningParticipant).isTrue();
        check(state.sessionStartedAtAdmission).equals(true);
      },
    );

    test(
      'permission and notification during an HTTP approval join only once',
      () async {
        final repository = _ServerRepository();
        final connection = _ServerConnection();
        final flow = _ServerFlow(repository, connection);
        _AdmissionFlow.connections = 0;
        _SuccessfulSessionController.activationCalls = 0;
        final container = _container(
          factory: _TrackFactory(),
          response: JoinResponse(
            token: 'token',
            isAlreadyPresent: false,
            admission: Omittable(_serverInitial()),
          ),
          sessionController: _SuccessfulSessionController.new,
          sessionOptions: serverOptions,
          flowController: () => flow,
        );
        addTearDown(() async {
          container.dispose();
          await flow.admission?.dispose();
        });
        await _waitForMedia(container);
        check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
        repository.waiting = Completer<AdmissionMeSnapshot>();
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        connection.hasMediaPermissions = true;
        connection.events.add(
          ServerAdmissionConnectionEvent.permissionsChanged,
        );
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        check(repository.reads).equals(1);
        check(_SuccessfulSessionController.activationCalls).equals(0);
        repository.current = _serverSnapshot('approved');
        repository.waiting!.complete(repository.current);
        await pumpEventQueue();
        check(_SuccessfulSessionController.activationCalls).equals(1);
        check(repository.activations).equals(1);
        check(_AdmissionFlow.connections).equals(1);
        check(
          container.read(preJoinFlowControllerProvider(_slug)).phase,
        ).equals(PreJoinFlowPhase.joined);
      },
    );

    test(
      'a transient activation receipt failure preserves the joined session and retries',
      () async {
        final repository = _ServerRepository()
          ..activationWaiting = Completer<AdmissionMeSnapshot>();
        final connection = _ServerConnection()..hasMediaPermissions = true;
        final flow = _ServerFlow(repository, connection);
        final session = _ResettableSessionController();
        final container = _container(
          factory: _TrackFactory(),
          response: JoinResponse(
            token: 'token',
            isAlreadyPresent: false,
            admission: Omittable(_serverInitial()),
          ),
          sessionController: () => session,
          sessionOptions: serverOptions,
          flowController: () => flow,
        );
        addTearDown(() async {
          container.dispose();
          await flow.admission?.dispose();
        });
        await _waitForMedia(container);
        check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
        repository.current = _serverSnapshot('approved');
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        await pumpEventQueue();
        repository.activationWaiting!.completeError(
          Exception('network failure'),
        );
        repository.activationWaiting = null;
        await pumpEventQueue();
        check(
          container.read(preJoinFlowControllerProvider(_slug)).phase,
        ).equals(PreJoinFlowPhase.joined);
        check(session.resets).equals(0);
        check(connection.disposed).isFalse();

        await flow.admission!.refresh(confirm: true);
        await pumpEventQueue();
        check(repository.activations).equals(2);
        check(
          container.read(preJoinFlowControllerProvider(_slug)).phase,
        ).equals(PreJoinFlowPhase.joined);
        check(session.resets).equals(0);
      },
    );

    test('a stale activation receipt never marks the flow joined', () async {
      final repository = _ServerRepository()
        ..activationWaiting = Completer<AdmissionMeSnapshot>();
      final connection = _ServerConnection()..hasMediaPermissions = true;
      final flow = _ServerFlow(repository, connection);
      final container = _container(
        factory: _TrackFactory(),
        response: JoinResponse(
          token: 'token',
          isAlreadyPresent: false,
          admission: Omittable(_serverInitial()),
        ),
        sessionController: _ResettableSessionController.new,
        flowController: () => flow,
      );
      addTearDown(() async {
        container.dispose();
        await flow.admission?.dispose();
      });
      await _waitForMedia(container);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      repository.current = _serverSnapshot('approved');
      connection.events.add(ServerAdmissionConnectionEvent.notification);
      await pumpEventQueue();
      check(repository.activations).equals(1);
      connection.isConnected = false;
      connection.events.add(ServerAdmissionConnectionEvent.disconnected);
      repository.activationWaiting!.complete(repository.current);
      await pumpEventQueue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).phase,
      ).equals(PreJoinFlowPhase.idle);
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error
            is StateError,
      ).isTrue();
    });

    test(
      'cancellation closes the waiting room and sends a server receipt',
      () async {
        final repository = _ServerRepository();
        final connection = _ServerConnection();
        final flow = _ServerFlow(repository, connection);
        final container = _container(
          factory: _TrackFactory(),
          response: JoinResponse(
            token: 'token',
            isAlreadyPresent: false,
            admission: Omittable(_serverInitial()),
          ),
          sessionController: _SuccessfulSessionController.new,
          flowController: () => flow,
        );
        addTearDown(container.dispose);
        await _waitForMedia(container);
        check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
        final room = flow.admissionRoom! as _AdmissionRoom;
        await flow.cancelAdmission();
        check(repository.cancellations).equals(1);
        check(connection.disposed).isTrue();
        check(room.disconnected).isTrue();
        check(room.disposed).isTrue();
        check(
          container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
        ).equals(AdmissionStatus.cancelled);
        check(repository.activations).equals(0);
      },
    );

    for (final failOldToken in [false, true]) {
      test(
        'cancelled token response cannot affect a newer admission (error: $failOldToken)',
        () async {
          final oldToken = Completer<JoinResponse>();
          final response = JoinResponse(
            token: 'token',
            isAlreadyPresent: false,
            admission: Omittable(_serverInitial()),
          );
          var calls = 0;
          final repository = _ServerRepository();
          final connection = _ServerConnection();
          final flow = _ServerFlow(repository, connection);
          _AdmissionFlow.connections = 0;
          final container = _container(
            factory: _TrackFactory(),
            response: response,
            getToken: () =>
                ++calls == 1 ? oldToken.future : Future.value(response),
            sessionController: _SuccessfulSessionController.new,
            flowController: () => flow,
          );
          addTearDown(container.dispose);
          await _waitForMedia(container);
          final oldJoin = flow.requestJoin();
          await pumpEventQueue();
          await flow.cancelAdmission();
          check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
          final room = flow.admissionRoom! as _AdmissionRoom;
          if (failOldToken) {
            oldToken.completeError(StateError('old token failed'));
          } else {
            oldToken.complete(response);
          }
          check(await oldJoin).equals(PreJoinJoinOutcome.ignored);
          check(_AdmissionFlow.connections).equals(1);
          check(room.disposed).isFalse();
          check(
            container.read(preJoinFlowControllerProvider(_slug)).phase,
          ).equals(PreJoinFlowPhase.pending);
          await flow.cancelAdmission();
        },
      );
    }

    test(
      'cancelled readiness cannot start a second room after retry',
      () async {
        final factory = _DelayedTrackFactory();
        final flow = _ServerFlow(_ServerRepository(), _ServerConnection());
        final response = JoinResponse(
          token: 'token',
          isAlreadyPresent: false,
          admission: Omittable(_serverInitial()),
        );
        _AdmissionFlow.connections = 0;
        final container = _container(
          factory: factory,
          response: response,
          sessionController: _SuccessfulSessionController.new,
          flowController: () => flow,
        );
        addTearDown(container.dispose);
        await factory.started.future;
        final oldJoin = flow.requestJoin();
        await pumpEventQueue();
        await flow.cancelAdmission();
        final newJoin = flow.requestJoin();
        factory.gate.complete();
        check(await oldJoin).equals(PreJoinJoinOutcome.ignored);
        check(await newJoin).equals(PreJoinJoinOutcome.pending);
        check(_AdmissionFlow.connections).equals(1);
        check((flow.admissionRoom! as _AdmissionRoom).disposed).isFalse();
        await flow.cancelAdmission();
      },
    );

    test('setup failure during cancellation still disposes the room', () async {
      final flow = _ServerFlow(_ServerRepository(), _ServerConnection());
      _AdmissionFlow.connectionStarted = Completer<void>();
      _AdmissionFlow.connectionGate = Completer<void>();
      _AdmissionFlow.failConnection = true;
      final container = _container(
        factory: _TrackFactory(),
        response: JoinResponse(
          token: 'token',
          isAlreadyPresent: false,
          admission: Omittable(_serverInitial()),
        ),
        sessionController: _SuccessfulSessionController.new,
        flowController: () => flow,
      );
      addTearDown(() {
        container.dispose();
        _AdmissionFlow.connectionStarted = null;
        _AdmissionFlow.connectionGate = null;
        _AdmissionFlow.failConnection = false;
      });
      await _waitForMedia(container);
      final joining = flow.requestJoin();
      await _AdmissionFlow.connectionStarted!.future;
      final room = flow.admissionRoom! as _AdmissionRoom;
      final cancelling = flow.cancelAdmission();
      _AdmissionFlow.connectionGate!.complete();
      check(await joining).equals(PreJoinJoinOutcome.ignored);
      await cancelling;
      check(room.disposed).isTrue();
      check(flow.connection.disposed).isTrue();
    });

    test('cancellation during connection setup closes the room', () async {
      final repository = _ServerRepository();
      final connection = _ServerConnection();
      final flow = _ServerFlow(repository, connection);
      _AdmissionFlow.connectionStarted = Completer<void>();
      _AdmissionFlow.connectionGate = Completer<void>();
      final container = _container(
        factory: _TrackFactory(),
        response: JoinResponse(
          token: 'token',
          isAlreadyPresent: false,
          admission: Omittable(_serverInitial()),
        ),
        sessionController: _SuccessfulSessionController.new,
        flowController: () => flow,
      );
      addTearDown(() {
        container.dispose();
        _AdmissionFlow.connectionStarted = null;
        _AdmissionFlow.connectionGate = null;
      });
      await _waitForMedia(container);
      final joining = flow.requestJoin();
      await _AdmissionFlow.connectionStarted!.future;
      final room = flow.admissionRoom! as _AdmissionRoom;
      final cancelling = flow.cancelAdmission();
      _AdmissionFlow.connectionGate!.complete();
      check(await joining).equals(PreJoinJoinOutcome.ignored);
      await cancelling;
      check(room.disposed).isTrue();
      check(connection.disposed).isTrue();
      check(repository.activations).equals(0);
    });

    test('server decline releases preview and prevents another join', () async {
      final factory = _TrackFactory();
      final repository = _ServerRepository();
      final connection = _ServerConnection();
      final flow = _ServerFlow(repository, connection);
      final container = _container(
        factory: factory,
        response: JoinResponse(
          token: 'token',
          isAlreadyPresent: false,
          admission: Omittable(_serverInitial()),
        ),
        sessionController: _SuccessfulSessionController.new,
        flowController: () => flow,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final room = flow.admissionRoom! as _AdmissionRoom;
      repository.current = _serverSnapshot('declined');
      connection.events.add(ServerAdmissionConnectionEvent.notification);
      await pumpEventQueue();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).admissionStatus,
      ).equals(AdmissionStatus.denied);
      check(room.disposed).isTrue();
      verify(factory.videoTracks.single.dispose).called(1);
      verify(factory.audioTracks.single.dispose).called(1);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.ignored);
    });

    test(
      'microphone lost while waiting prevents activation and closes room',
      () async {
        final factory = _TrackFactory();
        final repository = _ServerRepository();
        final connection = _ServerConnection()..hasMediaPermissions = true;
        final flow = _ServerFlow(repository, connection);
        _SuccessfulSessionController.activationCalls = 0;
        final container = _container(
          factory: factory,
          response: JoinResponse(
            token: 'token',
            isAlreadyPresent: false,
            admission: Omittable(_serverInitial()),
          ),
          sessionController: _SuccessfulSessionController.new,
          flowController: () => flow,
        );
        addTearDown(container.dispose);
        await _waitForMedia(container);
        check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
        final room = flow.admissionRoom! as _AdmissionRoom;
        factory.audioTracks.single.mockMediaStreamTrack.onEnded?.call();
        repository.current = _serverSnapshot('approved');
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        await pumpEventQueue();
        check(_SuccessfulSessionController.activationCalls).equals(0);
        check(repository.activations).equals(0);
        check(room.disposed).isTrue();
        check(
          container.read(preJoinFlowControllerProvider(_slug)).phase,
        ).equals(PreJoinFlowPhase.idle);
      },
    );

    test('failed session preload leaves preview tracks available', () async {
      final factory = _TrackFactory();
      final repository = _ServerRepository();
      final connection = _ServerConnection()..hasMediaPermissions = true;
      final flow = _ServerFlow(repository, connection);
      _SuccessfulSessionController.activationCalls = 0;
      final container = _container(
        factory: factory,
        response: JoinResponse(
          token: 'token',
          isAlreadyPresent: false,
          admission: Omittable(_serverInitial()),
        ),
        sessionController: _SuccessfulSessionController.new,
        flowController: () => flow,
        shouldFailPrecache: () => true,
      );
      addTearDown(container.dispose);
      await _waitForMedia(container);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      final room = flow.admissionRoom! as _AdmissionRoom;
      repository.current = _serverSnapshot('approved');
      connection.events.add(ServerAdmissionConnectionEvent.notification);
      await pumpEventQueue();
      check(_SuccessfulSessionController.activationCalls).equals(0);
      check(repository.activations).equals(0);
      check(room.disposed).isTrue();
      check(
        container.read(preJoinMediaControllerProvider(_slug)).transferred,
      ).isFalse();
      check(
        container.read(preJoinFlowControllerProvider(_slug)).error,
      ).isNotNull();
      verifyNever(factory.videoTracks.single.dispose);
      verifyNever(factory.audioTracks.single.dispose);
    });

    test('disposal fences a pending HTTP approval', () async {
      final repository = _ServerRepository();
      final connection = _ServerConnection()..hasMediaPermissions = true;
      final flow = _ServerFlow(repository, connection);
      _SuccessfulSessionController.activationCalls = 0;
      final container = _container(
        factory: _TrackFactory(),
        response: JoinResponse(
          token: 'token',
          isAlreadyPresent: false,
          admission: Omittable(_serverInitial()),
        ),
        sessionController: _SuccessfulSessionController.new,
        sessionOptions: serverOptions,
        flowController: () => flow,
      );
      await _waitForMedia(container);
      check(await flow.requestJoin()).equals(PreJoinJoinOutcome.pending);
      repository.waiting = Completer<AdmissionMeSnapshot>();
      connection.events.add(ServerAdmissionConnectionEvent.notification);
      check(repository.reads).equals(1);
      final room = flow.admissionRoom! as _AdmissionRoom;
      container.dispose();
      await pumpEventQueue();
      repository.waiting!.complete(_serverSnapshot('approved'));
      await pumpEventQueue();
      check(connection.disposed).isTrue();
      check(room.disconnected).isTrue();
      check(room.disposed).isTrue();
      check(_SuccessfulSessionController.activationCalls).equals(0);
      check(repository.activations).equals(0);
    });
  });

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
}
