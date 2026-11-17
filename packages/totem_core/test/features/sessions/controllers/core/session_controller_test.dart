import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:livekit_client/livekit_client.dart'
    as livekit
    show ConnectionState;
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_runtime.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/session_transport_factory_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../../../../auth/controllers/auth_controller_mock.dart';
import '../../../../setup.dart';
import '../../livekit_mocks.dart';
import '../../transport/fake_session_transport.dart';

class _MemoryAdmissionPreferences implements SessionAdmissionPreferences {
  final values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

SessionDetailSchema _createSessionEvent(String eventSlug) {
  return SessionDetailSchema(
    slug: eventSlug,
    title: 'Test session',
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
    start: DateTime(2026, 1, 1),
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

ProviderContainer _createContainerWithEventOverride(
  String eventSlug, {
  Future<SessionAdmissionPreferences>? admissionPreferences,
}) {
  final waitingRoom = RoomState(
    keeper: '',
    nextSpeaker: const Omittable(''),
    currentSpeaker: const Omittable(''),
    status: RoomStatus.waitingRoom,
    turnState: TurnState.idle,
    sessionSlug: eventSlug,
    statusDetail: const RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
    talkingOrder: const [],
    version: 0,
    roundNumber: 0,
  );
  return ProviderContainer(
    overrides: [
      if (admissionPreferences != null)
        sessionAdmissionPreferencesProvider.overrideWith(
          (_) => admissionPreferences,
        ),
      sessionProvider(
        eventSlug,
      ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
      authControllerProvider.overrideWith(
        () => FakeAuthController(AuthState.unauthenticated()),
      ),
      roomStateProvider(eventSlug).overrideWith((_) async => waitingRoom),
      roomStateProvider(
        eventSlug,
        attemptReconcile: true,
      ).overrideWith((_) async => waitingRoom),
    ],
  );
}

class _CountingRoomEventsListener implements EventsListener<RoomEvent> {
  int onCount = 0;
  int cancelAllCount = 0;
  int disposeCount = 0;
  final Map<Type, List<FutureOr<void> Function(Object?)>> _listeners = {};

  Set<Type> get listenerTypes => _listeners.keys.toSet();

  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) listener, {
    bool Function(E)? filter,
  }) {
    onCount++;
    _listeners.putIfAbsent(E, () => []).add((event) async {
      final typedEvent = event as E;
      if (filter == null || filter(typedEvent)) {
        await listener(typedEvent);
      }
    });
    return () async {};
  }

  Future<void> trigger<E>(E event) async {
    if (_listeners[E] == null) return;
    for (final listener in _listeners[E]!) {
      await listener(event);
    }
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }

  @override
  Future<bool> dispose() async {
    disposeCount++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _CountingRoom implements Room {
  _CountingRoom(
    this.participant, {
    this.prepareConnectionError,
    this.connectError,
    this.emitConnectedOnConnect = false,
    this.disconnectGate,
    this.disconnectError,
    this.emitDisconnectedOnDisconnect = false,
    this.disconnectedReason,
    this.remoteParticipantMap = const {},
    this.metadata,
    this.disconnectAfterFirstConnectionStateRead = false,
  });

  final MockLocalParticipant participant;
  final Error? prepareConnectionError;
  final LiveKitException? connectError;
  final bool emitConnectedOnConnect;
  final Completer<void>? disconnectGate;
  final Exception? disconnectError;
  final bool emitDisconnectedOnDisconnect;
  final DisconnectReason? disconnectedReason;
  final Map<String, RemoteParticipant> remoteParticipantMap;
  final bool disconnectAfterFirstConnectionStateRead;
  final _CountingRoomEventsListener listener = _CountingRoomEventsListener();

  int prepareConnectionCount = 0;
  int connectCount = 0;
  int disconnectCount = 0;
  int disposeCount = 0;
  int _connectionStateReads = 0;
  livekit.ConnectionState _connectionState = livekit.ConnectionState.connected;
  FastConnectOptions? lastFastConnectOptions;

  @override
  livekit.ConnectionState get connectionState {
    final currentState = _connectionState;
    if (disconnectAfterFirstConnectionStateRead &&
        _connectionStateReads++ == 0) {
      _connectionState = livekit.ConnectionState.disconnected;
    }
    return currentState;
  }

  @override
  LocalParticipant get localParticipant => participant;

  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(remoteParticipantMap);

  @override
  final String? metadata;

  @override
  RoomOptions get roomOptions => const RoomOptions();

  @override
  Future<void> prepareConnection(String url, String? token) async {
    prepareConnectionCount++;
    if (prepareConnectionError case final error?) throw error;
  }

  @override
  Future<void> connect(
    String url,
    String token, {
    ConnectOptions? connectOptions,
    FastConnectOptions? fastConnectOptions,
    RoomOptions? roomOptions,
  }) async {
    connectCount++;
    lastFastConnectOptions = fastConnectOptions;
    if (connectError case final error?) throw error;
    if (emitConnectedOnConnect) {
      await listener.trigger(RoomConnectedEvent(room: this, metadata: null));
    }
  }

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = true}) =>
      listener;

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    if (emitDisconnectedOnDisconnect) {
      await listener.trigger(RoomDisconnectedEvent(reason: disconnectedReason));
    }
    await disconnectGate?.future;
    if (disconnectError case final error?) throw error;
  }

  @override
  Future<bool> dispose() async {
    disposeCount++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RemoteParticipantWithPublications extends MockRemoteParticipant {
  _RemoteParticipantWithPublications(super.id, super.name, this.publications);

  final List<RemoteTrackPublication<RemoteTrack>> publications;

  @override
  List<RemoteTrackPublication<RemoteTrack>> getTrackPublications() {
    return publications;
  }
}

class _DelayedInitializeSessionController extends SessionController {
  final initializationStarted = Completer<void>();
  final initializationGate = Completer<void>();
  late Room initializedRoom;
  int initializationCount = 0;
  Error? initializationFailure;
  RoomOptions? lastRoomOptions;

  @override
  Future<SessionTransport> initializeConnection({
    required RoomOptions roomOptions,
    required String url,
    required String token,
    SessionAttempt? attempt,
  }) async {
    initializationCount++;
    lastRoomOptions = roomOptions;
    if (!initializationStarted.isCompleted) {
      initializationStarted.complete();
    }
    await initializationGate.future;
    attempt?.requireCurrent();
    if (initializationFailure case final failure?) throw failure;
    room = initializedRoom;
    return transport!;
  }
}

/// A controller that connects through [factory], kept alive for the test.
SessionController _transportController(
  SessionOptions options,
  FakeSessionTransportFactory factory,
) {
  late SessionController controller;
  final container = ProviderContainer(
    overrides: [
      sessionProvider(
        options.sessionSlug,
      ).overrideWithValue(AsyncData(_createSessionEvent(options.sessionSlug))),
      sessionTransportFactoryProvider(options).overrideWithValue(factory),
      roomStateProvider(
        options.sessionSlug,
      ).overrideWith((_) => controller.state.roomState),
      authControllerProvider.overrideWith(
        () => FakeAuthController(AuthState.unauthenticated()),
      ),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(sessionControllerProvider(options), (_, _) {});
  addTearDown(sub.close);
  return controller = container.read(
    sessionControllerProvider(options).notifier,
  );
}

void main() {
  setUpAll(() {
    setupAppConfig(
      liveKitUrl: 'wss://example.livekit.cloud',
      sentryDsn: 'test',
    );
  });

  group('SessionController', () {
    group('Connection Lifecycle', () {
      test(
        'production join uses the injected transport factory and typed lifecycle events',
        () async {
          const options = SessionOptions(
            sessionSlug: 'transport-session',
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            speakerEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
          );
          final factory = FakeSessionTransportFactory();
          late SessionController controller;
          final container = ProviderContainer(
            overrides: [
              sessionProvider(options.sessionSlug).overrideWithValue(
                AsyncData(_createSessionEvent(options.sessionSlug)),
              ),
              sessionTransportFactoryProvider(
                options,
              ).overrideWithValue(factory),
              roomStateProvider(
                options.sessionSlug,
              ).overrideWith((_) => controller.state.roomState),
              authControllerProvider.overrideWith(
                () => FakeAuthController(AuthState.unauthenticated()),
              ),
            ],
          );
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
          );
          controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          try {
            check(factory.created).isEmpty();
            check(await controller.join()).equals(SessionJoinResult.success);
            final transport = factory.created.single;
            final runtime = controller.runtime;
            container.invalidate(sessionTransportFactoryProvider(options));
            await container.pump();
            check(identical(controller.runtime, runtime)).isTrue();
            check(identical(controller.transport, transport)).isTrue();
            check(controller.room).isNull(); // No separate SDK room exists.
            check(transport.connectCalls).equals(1);
            check(
              controller.state.connectionState,
            ).equals(RoomConnectionState.connected);
            check(await controller.join()).equals(SessionJoinResult.success);
            check(factory.created).length.equals(1);
            check(transport.connectCalls).equals(1);
            const remote = ParticipantInfo(
              sid: 'remote-sid',
              identity: 'remote',
              name: 'Participant',
            );
            final admissionSync = controller.admission.synchronized;
            transport.emit(
              const TransportParticipantChanged(remote, present: true),
            );
            check(controller.state.participantsList).deepEquals([remote]);
            check(
              identical(controller.admission.synchronized, admissionSync),
            ).isTrue();
            final metadata = {
              ...controller.state.roomState.toJson(),
              'version': 23,
            };
            transport.emit(TransportMetadataChanged(jsonEncode(metadata)));
            check(controller.state.roomState.version).equals(23);
            final permissionUpdates = transport.permissionUpdates;
            const <SessionTransportEvent>[
              TransportConnectionChanged(
                SessionTransportConnectionState.reconnecting,
              ),
              TransportConnectionChanged(
                SessionTransportConnectionState.connected,
                reconnected: true,
              ),
            ].forEach(transport.emit);
            check(transport.permissionUpdates > permissionUpdates).isTrue();
            check(transport.connectCalls).equals(1);
            transport.emit(
              const TransportParticipantChanged(remote, present: false),
            );
            check(controller.state.participantsList).isEmpty();
            await controller.leave();
            await controller.disposeConnection();
            check(transport.disconnectCalls).equals(1);
            check(transport.underlyingDisposals).equals(1);
            check(controller.transport).isNull();
          } finally {
            subscription.close();
            container.dispose();
          }
        },
      );

      test(
        'transport connect failure retries through a new factory connection',
        () async {
          const options = SessionOptions(
            sessionSlug: 'retry-transport',
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            speakerEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
          );
          var attempts = 0;
          final factory = FakeSessionTransportFactory(
            configure: (transport) {
              if (attempts++ != 0) return;
              transport.connectFailure = const SessionTransportFailure(
                SessionTransportFailureKind.connection,
                'timeout',
                cause: 'test timeout',
                stackTrace: StackTrace.empty,
                connectionFailure: SessionTransportConnectionFailure.timeout,
              );
            },
          );
          late SessionController controller;
          final container = ProviderContainer(
            overrides: [
              sessionProvider(options.sessionSlug).overrideWithValue(
                AsyncData(_createSessionEvent(options.sessionSlug)),
              ),
              sessionTransportFactoryProvider(
                options,
              ).overrideWithValue(factory),
              roomStateProvider(
                options.sessionSlug,
              ).overrideWith((_) => controller.state.roomState),
              authControllerProvider.overrideWith(
                () => FakeAuthController(AuthState.unauthenticated()),
              ),
            ],
          );
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
          );
          controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          try {
            check(
              await controller.join(),
            ).equals(SessionJoinResult.retryableFailure);
            final failed = factory.created.single;
            final resetting = controller.resetAfterFailedJoin();
            final retrying = controller.join();
            await resetting;
            check(failed.underlyingDisposals).equals(1);
            check(await retrying).equals(SessionJoinResult.success);
            check(factory.created).length.equals(2);
            check(factory.created.last.connectCalls).equals(1);
            await controller.leave();
          } finally {
            await controller.disposeConnection();
            subscription.close();
            container.dispose();
          }
        },
      );

      for (final fails in [false, true]) {
        test(
          'production joins share the final connection outcome (failure: $fails)',
          () async {
            const options = SessionOptions(
              sessionSlug: 'single-flight',
              token: 'token',
              cameraEnabled: false,
              microphoneEnabled: false,
              speakerEnabled: true,
              cameraOptions: SessionController.defaultCameraCaptureOptions,
            );
            final started = Completer<void>();
            final gate = Completer<void>();
            final factory = FakeSessionTransportFactory(
              configure: (connection) {
                connection
                  ..connectStarted = started
                  ..connectCompletion = gate
                  ..connectFailure = fails
                      ? SessionTransportFailure(
                          SessionTransportFailureKind.connection,
                          'timeout',
                          cause: StateError('timeout'),
                          stackTrace: StackTrace.current,
                          connectionFailure:
                              SessionTransportConnectionFailure.timeout,
                        )
                      : null;
              },
            );
            final container = ProviderContainer(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
                sessionProvider(options.sessionSlug).overrideWithValue(
                  AsyncData(_createSessionEvent(options.sessionSlug)),
                ),
                sessionTransportFactoryProvider(
                  options,
                ).overrideWithValue(factory),
                roomStateProvider(options.sessionSlug).overrideWith(
                  (ref) =>
                      ref.read(sessionControllerProvider(options)).roomState,
                ),
              ],
            );
            final subscription = container.listen(
              sessionControllerProvider(options),
              (_, _) {},
            );
            final controller = container.read(
              sessionControllerProvider(options).notifier,
            );
            try {
              final first = controller.join();
              await started.future;
              var completed = false;
              final second = controller.join().then((result) {
                completed = true;
                return result;
              });
              await Future<void>.value();
              check(completed).isFalse();
              check(
                controller.state.connectionState,
              ).equals(RoomConnectionState.connecting);
              check(factory.created).length.equals(1);
              check(factory.created.single.connectCalls).equals(1);
              gate.complete();
              final result = fails
                  ? SessionJoinResult.retryableFailure
                  : SessionJoinResult.success;
              check(await first).equals(result);
              check(await second).equals(result);
              if (fails) await controller.resetAfterFailedJoin();
              await controller.leave();
              check(factory.created.single.underlyingDisposals).equals(1);
            } finally {
              subscription.close();
              container.dispose();
            }
          },
        );
      }

      test('transport rejection retains diagnostics and is fatal', () async {
        const options = SessionOptions(
          sessionSlug: 'transport-rejected',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          speakerEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
        );
        final failure = SessionTransportFailure(
          SessionTransportFailureKind.connection,
          'denied',
          cause: StateError('denied'),
          stackTrace: StackTrace.current,
          connectionFailure: SessionTransportConnectionFailure.notAllowed,
        );
        final factory = FakeSessionTransportFactory(
          configure: (transport) => transport.connectFailure = failure,
        );
        final container = ProviderContainer(
          overrides: [
            sessionProvider(options.sessionSlug).overrideWithValue(
              AsyncData(_createSessionEvent(options.sessionSlug)),
            ),
            sessionTransportFactoryProvider(options).overrideWithValue(factory),
          ],
        );
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
        );
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        try {
          check(await controller.join()).equals(SessionJoinResult.fatalFailure);
          final error =
              controller.state.connection.error! as RoomTransportError;
          check(error.failure).identicalTo(failure);
          check(factory.created.single.connectCalls).equals(1);
        } finally {
          await controller.disposeConnection();
          subscription.close();
          container.dispose();
        }
      });

      test(
        'initializeConnection assigns room and returns same instance',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );

          final initializedRoom = await controller.initializeConnection(
            roomOptions: RoomOptions(
              defaultCameraCaptureOptions: options.cameraOptions,
              defaultAudioCaptureOptions: const AudioCaptureOptions(),
              defaultAudioOutputOptions: AudioOutputOptions(
                speakerOn: options.speakerEnabled,
              ),
            ),
            url: 'wss://example.livekit.cloud',
            token: options.token,
          );

          check(controller.room).isNotNull();
          check(identical(controller.transport, initializedRoom)).equals(true);
        },
      );

      test('disposeConnection clears initialized room', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );

        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );

        await controller.initializeConnection(
          roomOptions: RoomOptions(
            defaultCameraCaptureOptions: options.cameraOptions,
            defaultAudioCaptureOptions: const AudioCaptureOptions(),
            defaultAudioOutputOptions: AudioOutputOptions(
              speakerOn: options.speakerEnabled,
            ),
          ),
          url: 'wss://example.livekit.cloud',
          token: options.token,
        );

        check(controller.room).isNotNull();
        await controller.disposeConnection();
        check(controller.room).isNull();
      });

      test('failed join waits for retained pre-join media disposal', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );

        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        final room = _CountingRoom(
          localParticipant,
          prepareConnectionError: StateError('prepare failed'),
        );
        controller.room = room;

        final cameraTrack = MockLocalVideoTrack();
        final microphoneTrack = MockLocalAudioTrack();
        final cameraDisposalGate = Completer<void>();
        when(cameraTrack.dispose).thenAnswer((_) async {
          await cameraDisposalGate.future;
          return true;
        });

        var joinCompleted = false;
        final joinFuture = controller
            .join(
              joinMedia: SessionJoinMedia(
                cameraTrack: cameraTrack,
                microphoneTrack: microphoneTrack,
              ),
            )
            .whenComplete(() => joinCompleted = true);
        await pumpEventQueue();

        check(joinCompleted).equals(false);
        verify(cameraTrack.stop).called(1);
        verify(cameraTrack.dispose).called(1);
        verify(microphoneTrack.stop).called(1);
        verify(microphoneTrack.dispose).called(1);

        cameraDisposalGate.complete();
        check(await joinFuture).equals(SessionJoinResult.retryableFailure);
        check(joinCompleted).equals(true);

        await controller.leave();
        check(controller.room).isNull();
        check(room.disconnectCount).equals(1);
        check(room.disposeCount).equals(1);
      });

      test('leaving on page exit signals LiveKit before any await', () {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final room = _CountingRoom(MockLocalParticipant());
        container.read(sessionControllerProvider(options).notifier)
          ..room = room
          // An unloading page runs nothing after the first await.
          ..leaveOnPageExit();

        check(room.disconnectCount).equals(1);
      });

      test('concurrent leave calls dispose the connection once', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        final room = _CountingRoom(localParticipant);
        controller.room = room;

        await Future.wait([controller.leave(), controller.leave()]);

        check(room.disposeCount).equals(1);
        check(controller.room).isNull();
      });

      test('concurrent leave calls share the in-flight disconnect', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        final disconnectGate = Completer<void>();
        final room = _CountingRoom(
          localParticipant,
          disconnectGate: disconnectGate,
        );
        controller.room = room;

        final firstLeave = controller.leave();
        await pumpEventQueue();
        final secondLeave = controller.leave();
        final thirdLeave = controller.leave();

        check(room.disconnectCount).equals(1);
        check(identical(firstLeave, secondLeave)).isTrue();
        check(identical(secondLeave, thirdLeave)).isTrue();
        disconnectGate.complete();
        await Future.wait([firstLeave, secondLeave, thirdLeave]);

        check(room.disposeCount).equals(1);
        check(controller.room).isNull();
      });

      test(
        'disconnect failure still cleans up and permits a later join',
        () async {
          const eventSlug = 'test-session';
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final container = ProviderContainer(
            overrides: [
              sessionProvider(
                eventSlug,
              ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
              authControllerProvider.overrideWith(
                () => FakeAuthController(AuthState.unauthenticated()),
              ),
              roomStateProvider(eventSlug).overrideWith(
                (ref) => ref.read(sessionControllerProvider(options)).roomState,
              ),
            ],
          );
          addTearDown(container.dispose);
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
          final failedRoom = _CountingRoom(
            localParticipant,
            disconnectError: TimeoutException('disconnect timed out'),
          );
          controller.room = failedRoom;

          await check(controller.leave()).throws<TimeoutException>();
          check(failedRoom.disposeCount).equals(1);
          check(controller.room).isNull();

          final disconnectRoom = _CountingRoom(
            localParticipant,
            disconnectError: TimeoutException('disconnect timed out'),
          );
          controller.room = disconnectRoom;
          await check(
            controller.disconnectFromRoom(),
          ).throws<TimeoutException>();
          check(disconnectRoom.disposeCount).equals(1);
          check(controller.room).isNull();

          final nextRoom = _CountingRoom(
            localParticipant,
            emitConnectedOnConnect: true,
          );
          controller.room = nextRoom;
          check(await controller.join()).equals(SessionJoinResult.success);
          check(nextRoom.connectCount).equals(1);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.connected);
          await controller.leave();
          check(nextRoom.disposeCount).equals(1);
        },
      );

      test(
        'session end transition leaves once and ignores repeated updates',
        () async {
          const eventSlug = 'test-session';
          final container = ProviderContainer(
            overrides: [
              authControllerProvider.overrideWith(
                () => FakeAuthController(AuthState.unauthenticated()),
              ),
              sessionProvider(
                eventSlug,
              ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
            ],
          );
          addTearDown(container.dispose);
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          final disconnectGate = Completer<void>();
          final room = _CountingRoom(
            localParticipant,
            disconnectGate: disconnectGate,
          );
          controller.room = room;
          const ended = RoomState(
            keeper: 'keeper',
            nextSpeaker: Omittable(''),
            currentSpeaker: Omittable(''),
            status: RoomStatus.ended,
            turnState: TurnState.idle,
            sessionSlug: eventSlug,
            statusDetail: RoomStateStatusDetailEnded(
              EndedDetail(reason: EndReason.keeperEnded),
            ),
            talkingOrder: [],
            version: 0,
            roundNumber: 0,
          );

          controller
            ..applyRoomState(ended)
            ..applyRoomState(ended);
          await pumpEventQueue();

          check(room.disconnectCount).equals(1);
          disconnectGate.complete();
          await pumpEventQueue();
          check(room.disposeCount).equals(1);
        },
      );

      test(
        'disconnect event during leave does not start another cleanup',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
          final room = _CountingRoom(
            localParticipant,
            emitConnectedOnConnect: true,
            emitDisconnectedOnDisconnect: true,
            disconnectedReason: DisconnectReason.duplicateIdentity,
          );
          controller.room = room;

          check(await controller.join()).equals(SessionJoinResult.success);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.connected);

          await controller.leave();

          check(room.disconnectCount).equals(1);
          check(room.disposeCount).equals(1);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.disconnected);
          check(controller.state.phase).equals(SessionPhase.disconnected);
          check(
            controller.state.disconnectReason,
          ).equals(DisconnectReason.duplicateIdentity);
        },
      );

      test('sequential leave calls clean up each new connection', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);

        final firstRoom = _CountingRoom(localParticipant);
        controller.room = firstRoom;
        await controller.leave();

        final secondRoom = _CountingRoom(localParticipant);
        controller.room = secondRoom;
        await controller.leave();

        check(firstRoom.disposeCount).equals(1);
        check(secondRoom.disposeCount).equals(1);
      });

      test(
        'transient join disconnect keeps room available for retry',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );

          final localParticipant = MockLocalParticipant();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);

          final room = _CountingRoom(localParticipant);
          controller.room = room;

          await controller.initializeConnection(
            roomOptions: RoomOptions(
              defaultCameraCaptureOptions: options.cameraOptions,
              defaultAudioCaptureOptions: const AudioCaptureOptions(),
              defaultAudioOutputOptions: AudioOutputOptions(
                speakerOn: options.speakerEnabled,
              ),
            ),
            url: 'wss://example.livekit.cloud',
            token: options.token,
          );

          await room.listener.trigger(
            RoomDisconnectedEvent(reason: DisconnectReason.joinFailure),
          );

          check(controller.room).identicalTo(room);
          check(room.disposeCount).equals(0);
          check(room.disconnectCount).equals(0);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.disconnected);
        },
      );

      group('reconnecting', () {
        const options = SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );

        Future<(SessionController, FakeSessionTransport)>
        connectedSession() async {
          final factory = FakeSessionTransportFactory();
          final controller = _transportController(options, factory);
          check(await controller.join()).equals(SessionJoinResult.success);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.connected);
          return (controller, factory.created.single);
        }

        test('tracks a reconnect until the transport recovers', () async {
          final (controller, transport) = await connectedSession();

          transport.emit(
            const TransportConnectionChanged(
              SessionTransportConnectionState.reconnecting,
            ),
          );
          check(controller.state.connection.isReconnecting).isTrue();
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.connected);

          transport.emit(
            const TransportConnectionChanged(
              SessionTransportConnectionState.connected,
              reconnected: true,
            ),
          );
          check(controller.state.connection.isReconnecting).isFalse();
        });

        test(
          'a reconnect that gives up leaves a technical disconnect',
          () async {
            final (controller, transport) = await connectedSession();

            transport
              ..emit(
                const TransportConnectionChanged(
                  SessionTransportConnectionState.reconnecting,
                ),
              )
              ..emit(
                const TransportConnectionChanged(
                  SessionTransportConnectionState.disconnected,
                  reason: SessionTransportDisconnectReason.mediaFailure,
                ),
              );

            check(controller.state.connection.isReconnecting).isFalse();
            check(
              controller.state.connectionState,
            ).equals(RoomConnectionState.disconnected);
            check(
              controller.state.disconnectReason,
            ).equals(DisconnectReason.mediaFailure);
            check(
              isTechnicalDisconnectReason(controller.state.disconnectReason),
            ).isTrue();
          },
        );
      });

      group('rejoin', () {
        const options = SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );

        test('retrying after a fatal join failure connects again', () async {
          var attempts = 0;
          final factory = FakeSessionTransportFactory(
            configure: (transport) {
              if (attempts++ != 0) return;
              transport.connectFailure = SessionTransportFailure(
                SessionTransportFailureKind.connection,
                'internal error',
                cause: StateError('internal error'),
                stackTrace: StackTrace.empty,
              );
            },
          );
          final controller = _transportController(options, factory);
          check(await controller.join()).equals(SessionJoinResult.fatalFailure);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.error);

          await controller.rejoin();

          check(factory.created).length.equals(2);
          check(factory.created.last.connectCalls).equals(1);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.connected);
          check(controller.state.connection.error).isNull();
        });

        test(
          'a failed rejoin without a LiveKit cause shows the error screen',
          () async {
            // On web, LiveKit's validate request fails like this when the
            // video server can't be reached.
            final failure = SessionTransportFailure(
              SessionTransportFailureKind.unexpected,
              'Failed to fetch',
              cause: ClientException('Failed to fetch'),
              stackTrace: StackTrace.empty,
            );
            final factory = FakeSessionTransportFactory(
              configure: (transport) => transport.connectFailure = failure,
            );
            final controller = _transportController(options, factory);

            await controller.rejoin();

            check(
              controller.state.connectionState,
            ).equals(RoomConnectionState.error);
            check(
              classifySessionError(controller.state.connection.error),
            ).equals(SessionErrorCategory.serverUnreachable);
          },
        );

        test('leaving during a rejoin does not report a failure', () async {
          final started = Completer<void>();
          final gate = Completer<void>();
          final factory = FakeSessionTransportFactory(
            configure: (transport) {
              transport
                ..connectStarted = started
                ..connectCompletion = gate;
            },
          );
          final controller = _transportController(options, factory);

          final rejoining = controller.rejoin();
          await started.future;
          final leaving = controller.leave();
          gate.complete();
          await leaving;
          await rejoining;

          check(factory.created.single.disconnectCalls).equals(1);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.disconnected);
          check(controller.state.connection.error).isNull();
        });
      });

      test('a failed rejoin from the error screen reports its cause', () async {
        const options = SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = _createContainerWithEventOverride('test-session');
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final timeout = ConnectException(
          'timed out',
          reason: ConnectionErrorReason.Timeout,
        );
        controller.room = _CountingRoom(
          MockLocalParticipant('me', 'Me'),
          connectError: timeout,
        );

        await controller.rejoin();

        // Not stuck connecting: the room shows its error screen again.
        check(
          controller.state.connectionState,
        ).equals(RoomConnectionState.error);
        check(controller.state.livekitError).identicalTo(timeout);
      });

      test('a failed join keeps its cause for the pre-join note', () async {
        const options = SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = _createContainerWithEventOverride('test-session');
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final timeout = ConnectException(
          'timed out',
          reason: ConnectionErrorReason.Timeout,
        );
        controller.room = _CountingRoom(
          MockLocalParticipant('me', 'Me'),
          connectError: timeout,
        );

        check(
          await controller.join(),
        ).equals(SessionJoinResult.retryableFailure);
        final failure = controller.lastJoinFailure;
        check(failure).isA<SessionTransportFailure>();
        check((failure! as SessionTransportFailure).cause).identicalTo(timeout);
        check(
          SessionJoinFailure(failure).kind,
        ).equals(SessionErrorCategory.serverUnreachable);
      });

      test(
        'a failed activation keeps a cause the runtime caught for the note',
        () async {
          const options = SessionOptions(
            sessionSlug: 'test-session',
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final container = _createContainerWithEventOverride('test-session');
          addTearDown(container.dispose);
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
          // Connected when offered, gone by the time the runtime claims it.
          final room = _CountingRoom(
            localParticipant,
            disconnectAfterFirstConnectionStateRead: true,
          );

          check(
            await controller.activateConnectedRoom(room: room),
          ).equals(SessionJoinResult.retryableFailure);
          check(controller.lastJoinFailure).isA<StateError>();

          // The next attempt doesn't inherit the old cause.
          check(await controller.resetAfterFailedJoin()).isTrue();
          check(
            await controller.activateConnectedRoom(
              room: _CountingRoom(localParticipant),
            ),
          ).equals(SessionJoinResult.success);
          check(controller.lastJoinFailure).isNull();
          await controller.leave();
        },
      );

      test('a participant renaming themselves updates the list', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );

        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant('me', 'Before');
        final room = _CountingRoom(localParticipant);
        controller.room = room;
        await controller.initializeConnection(
          roomOptions: const RoomOptions(),
          url: 'wss://example.livekit.cloud',
          token: options.token,
        );

        await room.listener.trigger(
          RoomConnectedEvent(room: room, metadata: null),
        );
        check(
          controller.state.participantsList.map((p) => p.name),
        ).deepEquals(['Before']);

        localParticipant.participantName = 'After';
        await room.listener.trigger(
          ParticipantNameUpdatedEvent(
            participant: localParticipant,
            name: 'After',
          ),
        );

        check(
          controller.state.participantsList.map((p) => p.name),
        ).deepEquals(['After']);
      });

      test(
        'RoomConnected never duplicates initial camera or microphone enablement',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          when(localParticipant.isMicrophoneEnabled).thenReturn(false);
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);

          final room = _CountingRoom(localParticipant);
          controller.room = room;
          await controller.initializeConnection(
            roomOptions: RoomOptions(
              defaultCameraCaptureOptions: options.cameraOptions,
              defaultAudioCaptureOptions: const AudioCaptureOptions(),
              defaultAudioOutputOptions: AudioOutputOptions(
                speakerOn: options.speakerEnabled,
              ),
            ),
            url: 'wss://example.livekit.cloud',
            token: options.token,
          );

          check(room.listener.listenerTypes.contains(RoomEvent)).isFalse();
          check(
            room.listener.listenerTypes.contains(RoomMetadataChangedEvent),
          ).isTrue();

          await room.listener.trigger(
            RoomConnectedEvent(room: room, metadata: null),
          );
          await pumpEventQueue();

          verifyNever(() => localParticipant.setCameraEnabled(any<bool>()));
          verifyNever(() => localParticipant.setMicrophoneEnabled(any<bool>()));
        },
      );

      test(
        'mutes restricted microphone media before explicit publication',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();
          final microphonePublication = MockLocalAudioTrackPublication();
          when(() => microphonePublication.track).thenReturn(microphoneTrack);
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.publishVideoTrack(
              cameraTrack,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          ).thenAnswer((_) async => MockLocalTrackPublication());
          var microphonePublished = false;
          when(
            () => localParticipant.publishAudioTrack(microphoneTrack),
          ).thenAnswer((_) async {
            microphonePublished = true;
            return microphonePublication;
          });
          when(
            () => localParticipant.getTrackPublicationBySource(
              TrackSource.microphone,
            ),
          ).thenAnswer(
            (_) => microphonePublished ? microphonePublication : null,
          );
          when(
            () => localParticipant.setMicrophoneEnabled(
              false,
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          ).thenAnswer((_) async => null);

          final room = _CountingRoom(localParticipant);
          controller
            ..room = room
            ..applyRoomState(
              const RoomState(
                keeper: 'keeper',
                nextSpeaker: Omittable(''),
                currentSpeaker: Omittable('another-participant'),
                status: RoomStatus.active,
                turnState: TurnState.idle,
                sessionSlug: eventSlug,
                statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
                talkingOrder: [],
                version: 1,
                roundNumber: 1,
              ),
            );

          check(
            await controller.join(
              joinMedia: SessionJoinMedia(
                cameraTrack: cameraTrack,
                microphoneTrack: microphoneTrack,
              ),
            ),
          ).equals(SessionJoinResult.success);

          verifyInOrder([
            () => microphoneTrack.mute(stopOnMute: false),
            () => localParticipant.publishAudioTrack(microphoneTrack),
          ]);
          // Published muted, then muted again in case anything unmuted it
          // while it published; never unmuted.
          verify(
            () => localParticipant.setMicrophoneEnabled(
              false,
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          ).called(1);
          verifyNever(
            () => localParticipant.setMicrophoneEnabled(
              true,
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          );
          verifyNever(() => localParticipant.setCameraEnabled(any<bool>()));
        },
      );

      test(
        'camera-off activation publishes existing microphone and becomes connected',
        () async {
          const eventSlug = 'test-session';
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final participant = MockLocalParticipant();
          final microphoneTrack = MockLocalAudioTrack();
          final publication =
              Completer<LocalTrackPublication<LocalAudioTrack>>();
          when(participant.isMicrophoneEnabled).thenReturn(true);
          when(
            () => participant.publishAudioTrack(microphoneTrack),
          ).thenAnswer((_) => publication.future);
          when(
            () => participant.setMicrophoneEnabled(
              false,
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          ).thenAnswer((_) async => null);
          when(participant.unpublishAllTracks).thenAnswer((_) async {});
          final room = _CountingRoom(participant);

          final activation = controller.activateConnectedRoom(
            room: room,
            joinMedia: SessionJoinMedia(microphoneTrack: microphoneTrack),
          );
          await pumpEventQueue();
          verify(
            () => participant.publishAudioTrack(microphoneTrack),
          ).called(1);
          verifyNever(
            () => participant.setMicrophoneEnabled(
              false,
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          );
          publication.complete(MockLocalAudioTrackPublication());
          check(await activation).equals(SessionJoinResult.success);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.connected);
          verifyNever(() => participant.setCameraEnabled(any<bool>()));
          await controller.leave();
        },
      );

      test(
        'activation applies room metadata without waiting for server poll',
        () async {
          const eventSlug = 'test-session';
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          const roomState = RoomState(
            keeper: 'keeper',
            nextSpeaker: Omittable(''),
            currentSpeaker: Omittable(''),
            status: RoomStatus.active,
            turnState: TurnState.idle,
            sessionSlug: eventSlug,
            statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
            talkingOrder: [],
            version: 1,
            roundNumber: 1,
          );
          final poll = Completer<RoomState>();
          var pollStarted = false;
          final container = ProviderContainer(
            overrides: [
              sessionProvider(
                eventSlug,
              ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
              roomStateProvider(eventSlug).overrideWith((_) {
                pollStarted = true;
                return poll.future;
              }),
            ],
          );
          addTearDown(container.dispose);
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(subscription.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final participant = MockLocalParticipant();
          when(participant.unpublishAllTracks).thenAnswer((_) async {});
          when(
            () => participant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => participant.setMicrophoneEnabled(
              false,
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          ).thenAnswer((_) async => null);
          final room = _CountingRoom(
            participant,
            metadata: jsonEncode(roomState.toJson()),
          );
          SessionJoinResult? result;
          final activation = controller.activateConnectedRoom(room: room).then((
            value,
          ) {
            result = value;
          });
          try {
            await pumpEventQueue();
            check(pollStarted).isTrue();
            check(poll.isCompleted).isFalse();
            check(result).equals(SessionJoinResult.success);
            check(controller.state.roomState.status).equals(RoomStatus.active);
            check(controller.state.roomState.version).equals(1);
          } finally {
            poll.complete(roomState);
            await activation;
            await controller.leave();
          }
        },
      );

      test('adopts an already-connected room only once', () async {
        const eventSlug = 'test-session';
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
        final room = _CountingRoom(localParticipant);

        check(
          await controller.activateConnectedRoom(room: room),
        ).equals(SessionJoinResult.success);
        final initialListenerCount = room.listener.onCount;
        check(
          await controller.activateConnectedRoom(room: room),
        ).equals(SessionJoinResult.success);

        final rejectedRoom = _CountingRoom(MockLocalParticipant());
        check(
          await controller.activateConnectedRoom(room: rejectedRoom),
        ).equals(SessionJoinResult.retryableFailure);

        check(room.prepareConnectionCount).equals(0);
        check(room.connectCount).equals(0);
        check(room.listener.onCount).equals(initialListenerCount);
        check(rejectedRoom.disconnectCount).equals(1);
        check(rejectedRoom.disposeCount).equals(1);
        check(room.disposeCount).equals(0);
        await controller.leave();
        check(room.disposeCount).equals(1);
      });

      test('activating the live room while it reconnects keeps it', () async {
        const options = SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = _createContainerWithEventOverride('test-session');
        addTearDown(container.dispose);
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
        final room = _CountingRoom(localParticipant);
        check(
          await controller.activateConnectedRoom(room: room),
        ).equals(SessionJoinResult.success);
        await room.listener.trigger(const RoomReconnectingEvent());
        check(
          controller.runtime.phase,
        ).equals(SessionRuntimePhase.reconnecting);

        check(
          await controller.activateConnectedRoom(room: room),
        ).equals(SessionJoinResult.success);

        check(room.disconnectCount).equals(0);
        check(room.disposeCount).equals(0);
        check(
          controller.runtime.phase,
        ).equals(SessionRuntimePhase.reconnecting);
        await controller.leave();
      });

      test('claims an offered room before a prior leave finishes', () async {
        const eventSlug = 'test-session';
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final previousParticipant = MockLocalParticipant();
        when(previousParticipant.unpublishAllTracks).thenAnswer((_) async {});
        final disconnectGate = Completer<void>();
        controller.room = _CountingRoom(
          previousParticipant,
          disconnectGate: disconnectGate,
        );
        final previousLeave = controller.leave();
        await pumpEventQueue();

        final publication = MockRemoteTrackPublication<RemoteTrack>();
        when(publication.subscribe).thenAnswer((_) async {});
        final offeredParticipant = _RemoteParticipantWithPublications(
          'remote',
          'Remote',
          [publication],
        );
        final offeredLocalParticipant = MockLocalParticipant();
        when(
          offeredLocalParticipant.unpublishAllTracks,
        ).thenAnswer((_) async {});
        final offeredRoom = _CountingRoom(
          offeredLocalParticipant,
          remoteParticipantMap: {'remote': offeredParticipant},
        );
        final activation = controller.activateConnectedRoom(room: offeredRoom);
        await pumpEventQueue();

        final rejectedRoom = _CountingRoom(MockLocalParticipant());
        check(
          await controller.activateConnectedRoom(room: rejectedRoom),
        ).equals(SessionJoinResult.retryableFailure);
        verifyNever(publication.subscribe);
        check(rejectedRoom.disposeCount).equals(1);

        disconnectGate.complete();
        await previousLeave;
        check(await activation).equals(SessionJoinResult.success);
        await pumpEventQueue();
        verify(publication.subscribe).called(1);
      });

      test(
        'caller cleans up a disconnected adopted room; unadopted rooms are released',
        () async {
          const eventSlug = 'test-session';
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(subscription.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
          final room = _CountingRoom(
            localParticipant,
            disconnectAfterFirstConnectionStateRead: true,
          );

          check(
            await controller.activateConnectedRoom(room: room),
          ).equals(SessionJoinResult.retryableFailure);
          check(room.disposeCount).equals(1);
          check(controller.room).isNull();

          await controller.resetAfterFailedJoin();
          check(room.disposeCount).equals(1);
          check(controller.room).isNull();

          final unadoptedRoom = _CountingRoom(localParticipant)
            .._connectionState = livekit.ConnectionState.disconnected;
          check(
            await controller.activateConnectedRoom(room: unadoptedRoom),
          ).equals(SessionJoinResult.retryableFailure);
          check(unadoptedRoom.disposeCount).equals(1);
          check(controller.room).isNull();
          await controller.resetAfterFailedJoin();
          check(unadoptedRoom.disposeCount).equals(1);
        },
      );

      test('leaves adopted room cleanup to the failed-join caller', () async {
        const eventSlug = 'test-session';
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
        final room = _CountingRoom(localParticipant);

        check(
          await controller.activateConnectedRoom(room: room),
        ).equals(SessionJoinResult.retryableFailure);

        check(room.prepareConnectionCount).equals(0);
        check(room.connectCount).equals(0);
        check(room.disposeCount).equals(0);
        check(identical(controller.room, room)).isTrue();

        await controller.resetAfterFailedJoin();
        check(room.disposeCount).equals(1);
        check(controller.room).isNull();
      });

      test('subscribes once per publication until it is unpublished', () async {
        const eventSlug = 'test-session';
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final existingPublication = MockRemoteTrackPublication<RemoteTrack>();
        final publishedPublication = MockRemoteTrackPublication<RemoteTrack>();
        when(existingPublication.subscribe).thenAnswer((_) async {});
        when(publishedPublication.subscribe).thenAnswer((_) async {});
        final participant = _RemoteParticipantWithPublications(
          'remote',
          'Remote',
          [existingPublication],
        );
        final localParticipant = MockLocalParticipant();
        when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
        final room = _CountingRoom(
          localParticipant,
          remoteParticipantMap: {'remote': participant},
        );
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );

        check(
          await controller.activateConnectedRoom(room: room),
        ).equals(SessionJoinResult.success);
        await pumpEventQueue();
        await room.listener.trigger(
          TrackPublishedEvent(
            participant: participant,
            publication: publishedPublication,
          ),
        );
        await room.listener.trigger(
          TrackPublishedEvent(
            participant: participant,
            publication: publishedPublication,
          ),
        );
        await pumpEventQueue();

        verify(existingPublication.subscribe).called(1);
        verify(publishedPublication.subscribe).called(1);

        await room.listener.trigger(
          TrackUnpublishedEvent(
            participant: participant,
            publication: publishedPublication,
          ),
        );
        await room.listener.trigger(
          TrackPublishedEvent(
            participant: participant,
            publication: publishedPublication,
          ),
        );
        await pumpEventQueue();
        verify(publishedPublication.subscribe).called(1);
      });

      test(
        'retries failed remote subscriptions without clearing a newer attempt',
        () async {
          const eventSlug = 'test-session';
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final firstAttempt = Completer<void>();
          final secondAttempt = Completer<void>();
          var subscribeAttempts = 0;
          final publication = MockRemoteTrackPublication<RemoteTrack>();
          when(publication.subscribe).thenAnswer((_) {
            subscribeAttempts++;
            return switch (subscribeAttempts) {
              1 => firstAttempt.future,
              2 => secondAttempt.future,
              _ => Future.value(),
            };
          });
          final participant = _RemoteParticipantWithPublications(
            'remote',
            'Remote',
            [publication],
          );
          final localParticipant = MockLocalParticipant();
          when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
          final room = _CountingRoom(
            localParticipant,
            remoteParticipantMap: {'remote': participant},
          );
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(subscription.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );

          check(
            await controller.activateConnectedRoom(room: room),
          ).equals(SessionJoinResult.success);
          await pumpEventQueue();
          check(subscribeAttempts).equals(1);

          await room.listener.trigger(
            TrackUnpublishedEvent(
              participant: participant,
              publication: publication,
            ),
          );
          await room.listener.trigger(
            TrackPublishedEvent(
              participant: participant,
              publication: publication,
            ),
          );
          await pumpEventQueue();
          check(subscribeAttempts).equals(2);

          firstAttempt.completeError(StateError('first subscription failed'));
          await pumpEventQueue();
          await room.listener.trigger(
            TrackPublishedEvent(
              participant: participant,
              publication: publication,
            ),
          );
          await pumpEventQueue();
          check(subscribeAttempts).equals(2);

          secondAttempt.completeError(StateError('second subscription failed'));
          await pumpEventQueue();
          await room.listener.trigger(
            TrackPublishedEvent(
              participant: participant,
              publication: publication,
            ),
          );
          await pumpEventQueue();
          check(subscribeAttempts).equals(3);
        },
      );

      test(
        'limits participant media to the keeper and admitted roster',
        () async {
          const eventSlug = 'test-session';
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final container = _createContainerWithEventOverride(
            eventSlug,
            admissionPreferences: Future.value(_MemoryAdmissionPreferences()),
          );
          addTearDown(container.dispose);
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(subscription.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant('participant');
          when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
          final room = _CountingRoom(localParticipant);
          controller.applyRoomState(
            const RoomState(
              keeper: 'keeper',
              nextSpeaker: Omittable(''),
              currentSpeaker: Omittable(''),
              status: RoomStatus.waitingRoom,
              turnState: TurnState.idle,
              sessionSlug: eventSlug,
              statusDetail: RoomStateStatusDetailWaitingRoom(
                WaitingRoomDetail(),
              ),
              talkingOrder: [],
              version: 1,
              roundNumber: 0,
            ),
          );

          check(
            await controller.activateConnectedRoom(room: room),
          ).equals(SessionJoinResult.success);
          final initialPermissions =
              verify(
                    () => localParticipant.setTrackSubscriptionPermissions(
                      allParticipantsAllowed: false,
                      trackPermissions: captureAny(named: 'trackPermissions'),
                    ),
                  ).captured.single
                  as List<ParticipantTrackPermission>;
          check(
            initialPermissions.map(
              (permission) => permission.participantIdentity,
            ),
          ).unorderedEquals(['keeper']);
          // This tests the media permission projection independently of the
          // admission protocol, which otherwise updates recipients on reconnect.
          await controller.admission.close();
          clearInteractions(localParticipant);

          controller
            ..updateAdmittedMediaRecipients({'admitted', 'participant'})
            ..updateAdmittedMediaRecipients({'admitted', 'participant'});
          final captured =
              verify(
                    () => localParticipant.setTrackSubscriptionPermissions(
                      allParticipantsAllowed: false,
                      trackPermissions: captureAny(named: 'trackPermissions'),
                    ),
                  ).captured.single
                  as List<ParticipantTrackPermission>;
          check(
            captured.map((permission) => permission.participantIdentity),
          ).unorderedEquals(['admitted', 'keeper']);

          await room.listener.trigger(
            LocalTrackPublishedEvent(
              participant: localParticipant,
              publication: MockLocalTrackPublication(),
            ),
          );
          await room.listener.trigger(const RoomReconnectedEvent());

          verify(
            () => localParticipant.setTrackSubscriptionPermissions(
              allParticipantsAllowed: false,
              trackPermissions: any(named: 'trackPermissions'),
            ),
          ).called(2);
        },
      );

      test(
        'allows keeper media until authority loads, then restricts it',
        () async {
          const eventSlug = 'test-session';
          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final preferencesReady = Completer<SessionAdmissionPreferences>();
          final container = ProviderContainer(
            overrides: [
              sessionAdmissionPreferencesProvider.overrideWith(
                (_) => preferencesReady.future,
              ),
              authControllerProvider.overrideWith(
                () => FakeAuthController(AuthState.unauthenticated()),
              ),
              sessionProvider(
                eventSlug,
              ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(() {
            if (!preferencesReady.isCompleted) {
              preferencesReady.complete(_MemoryAdmissionPreferences());
            }
          });
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(subscription.close);
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant('keeper');
          when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
          final room = _CountingRoom(localParticipant);
          controller.applyRoomState(
            const RoomState(
              keeper: 'keeper',
              nextSpeaker: Omittable(''),
              currentSpeaker: Omittable(''),
              status: RoomStatus.waitingRoom,
              turnState: TurnState.idle,
              sessionSlug: eventSlug,
              statusDetail: RoomStateStatusDetailWaitingRoom(
                WaitingRoomDetail(),
              ),
              talkingOrder: [],
              version: 1,
              roundNumber: 0,
            ),
          );

          check(
            await controller.activateConnectedRoom(room: room),
          ).equals(SessionJoinResult.success);
          final initialPermissions =
              verify(
                    () => localParticipant.setTrackSubscriptionPermissions(
                      allParticipantsAllowed: true,
                      trackPermissions: captureAny(named: 'trackPermissions'),
                    ),
                  ).captured.single
                  as List<ParticipantTrackPermission>;
          check(initialPermissions).isEmpty();
          clearInteractions(localParticipant);

          await room.listener.trigger(
            LocalTrackPublishedEvent(
              participant: localParticipant,
              publication: MockLocalTrackPublication(),
            ),
          );
          await room.listener.trigger(const RoomReconnectedEvent());
          final fallbackPermissions = verify(
            () => localParticipant.setTrackSubscriptionPermissions(
              allParticipantsAllowed: true,
              trackPermissions: captureAny(named: 'trackPermissions'),
            ),
          ).captured.cast<List<ParticipantTrackPermission>>();
          check(fallbackPermissions.length).equals(2);
          for (final permissions in fallbackPermissions) {
            check(permissions).isEmpty();
          }
          clearInteractions(localParticipant);

          final authorityReady = Completer<void>();
          void observeAuthority() {
            if (controller.admission.keeperController != null &&
                !authorityReady.isCompleted) {
              authorityReady.complete();
            }
          }

          controller.admission.addListener(observeAuthority);
          try {
            preferencesReady.complete(_MemoryAdmissionPreferences());
            observeAuthority();
            await authorityReady.future;
          } finally {
            controller.admission.removeListener(observeAuthority);
          }
          final emptyRosterPermissions =
              verify(
                    () => localParticipant.setTrackSubscriptionPermissions(
                      allParticipantsAllowed: false,
                      trackPermissions: captureAny(named: 'trackPermissions'),
                    ),
                  ).captured.single
                  as List<ParticipantTrackPermission>;
          check(emptyRosterPermissions).isEmpty();
          await controller.admission.close();
          clearInteractions(localParticipant);

          controller.updateAdmittedMediaRecipients({'keeper', 'admitted'});
          final admittedPermissions =
              verify(
                    () => localParticipant.setTrackSubscriptionPermissions(
                      allParticipantsAllowed: false,
                      trackPermissions: captureAny(named: 'trackPermissions'),
                    ),
                  ).captured.single
                  as List<ParticipantTrackPermission>;
          check(
            admittedPermissions.map(
              (permission) => permission.participantIdentity,
            ),
          ).unorderedEquals(['admitted']);
        },
      );

      test('keeper reconciles admitted participant connections only', () async {
        const eventSlug = 'test-session';
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        const roomState = RoomState(
          keeper: 'keeper',
          nextSpeaker: Omittable(''),
          currentSpeaker: Omittable(''),
          status: RoomStatus.waitingRoom,
          turnState: TurnState.idle,
          sessionSlug: eventSlug,
          statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
          talkingOrder: [],
          version: 1,
          roundNumber: 0,
        );
        var reconcilePolls = 0;
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(
                AuthState.authenticated(
                  user: UserSchema(
                    email: 'keeper@example.com',
                    slug: const Omittable('keeper'),
                    name: const Omittable('Keeper'),
                    profileAvatarType: ProfileAvatarTypeEnum.td,
                    circleCount: 0,
                    dateCreated: DateTime(2024),
                  ),
                ),
              ),
            ),
            sessionProvider(
              eventSlug,
            ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
            roomStateProvider(eventSlug).overrideWith((_) async => roomState),
            roomStateProvider(eventSlug, attemptReconcile: true).overrideWith((
              _,
            ) async {
              reconcilePolls++;
              return roomState;
            }),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant('keeper');
        final admittedParticipant = _RemoteParticipantWithPublications(
          'admitted',
          'Admitted',
          const [],
        );
        when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
        final room = _CountingRoom(
          localParticipant,
          remoteParticipantMap: {'admitted': admittedParticipant},
        );
        controller.applyRoomState(roomState);

        check(
          await controller.activateConnectedRoom(room: room),
        ).equals(SessionJoinResult.success);
        await pumpEventQueue();
        reconcilePolls = 0;
        controller.updateAdmittedMediaRecipients({'admitted'});
        await pumpEventQueue();
        check(reconcilePolls).equals(1);

        controller.updateAdmittedMediaRecipients({'admitted'});
        await pumpEventQueue();
        check(reconcilePolls).equals(1);

        await room.listener.trigger(
          ParticipantConnectedEvent(
            participant: MockRemoteParticipant('pending', 'Pending'),
          ),
        );
        await pumpEventQueue();
        check(reconcilePolls).equals(1);

        await room.listener.trigger(
          ParticipantConnectedEvent(
            participant: MockRemoteParticipant('admitted', 'Admitted'),
          ),
        );
        await pumpEventQueue();
        check(reconcilePolls).equals(2);
      });

      test('join only calls room.connect once while connecting', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );

        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);

        final room = _CountingRoom(localParticipant);
        controller.room = room;

        await controller.join();
        await controller.join();
        await controller.join();
        await controller.join();

        check(room.prepareConnectionCount).equals(1);
        check(room.connectCount).equals(1);
      });

      test('join succeeds when connected without pre-join media', () async {
        const eventSlug = 'test-session';
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final subscription = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(localParticipant.unpublishAllTracks).thenAnswer((_) async {});
        final room = _CountingRoom(
          localParticipant,
          emitConnectedOnConnect: true,
        );
        controller.room = room;

        check(await controller.join()).equals(SessionJoinResult.success);
        check(room.connectCount).equals(1);
        check(
          container.read(sessionControllerProvider(options)).connection.state,
        ).equals(RoomConnectionState.connected);
      });

      test('server-side mutes keep the microphone captured', () async {
        // The backend mutes participants through LiveKit, and the SDK applies
        // those mutes with the room's default capture options. A stopped
        // microphone would stay silent after the next soft unmute.
        const eventSlug = 'test-session';
        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: false,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );
        final container = ProviderContainer(
          overrides: [
            sessionProvider(
              eventSlug,
            ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
            sessionControllerProvider(
              options,
            ).overrideWith(_DelayedInitializeSessionController.new),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final controller =
            container.read(sessionControllerProvider(options).notifier)
                  as _DelayedInitializeSessionController
              ..initializedRoom = _CountingRoom(MockLocalParticipant());

        final join = controller.join();
        await controller.initializationStarted.future;

        check(controller.lastRoomOptions?.defaultAudioCaptureOptions)
            .isNotNull()
            .has((o) => o.stopAudioCaptureOnMute, 'stopAudioCaptureOnMute')
            .isFalse();

        controller.initializationGate.complete();
        await join;
      });

      for (final initializationFails in [false, true]) {
        test(
          'blocked initialization shares its final result and media ownership (failure: $initializationFails)',
          () async {
            const eventSlug = 'test-session';
            const options = SessionOptions(
              sessionSlug: eventSlug,
              token: 'test-token',
              cameraEnabled: true,
              microphoneEnabled: true,
              cameraOptions: SessionController.defaultCameraCaptureOptions,
              speakerEnabled: true,
            );
            final container = ProviderContainer(
              overrides: [
                sessionProvider(
                  eventSlug,
                ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
                sessionControllerProvider(
                  options,
                ).overrideWith(_DelayedInitializeSessionController.new),
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
                roomStateProvider(eventSlug).overrideWith(
                  (ref) =>
                      ref.read(sessionControllerProvider(options)).roomState,
                ),
              ],
            );
            addTearDown(container.dispose);

            final sub = container.listen(
              sessionControllerProvider(options),
              (_, _) {},
              fireImmediately: true,
            );
            addTearDown(sub.close);

            final controller =
                container.read(sessionControllerProvider(options).notifier)
                    as _DelayedInitializeSessionController;
            if (initializationFails) {
              controller.initializationFailure = StateError(
                'initialization rejected',
              );
            }
            final localParticipant = MockLocalParticipant();
            when(
              () => localParticipant.setCameraEnabled(any<bool>()),
            ).thenAnswer((_) async => null);
            when(
              () => localParticipant.setMicrophoneEnabled(any<bool>()),
            ).thenAnswer((_) async => null);
            final room = _CountingRoom(localParticipant);
            controller.initializedRoom = room;

            final firstCameraTrack = MockLocalVideoTrack();
            final firstMicrophoneTrack = MockLocalAudioTrack();
            when(
              () => localParticipant.publishVideoTrack(
                firstCameraTrack,
                publishOptions: SessionController.defaultVideoPublishOptions,
              ),
            ).thenAnswer((_) async => MockLocalTrackPublication());
            when(
              () => localParticipant.publishAudioTrack(firstMicrophoneTrack),
            ).thenAnswer((_) async => MockLocalAudioTrackPublication());
            final firstJoin = controller.join(
              joinMedia: SessionJoinMedia(
                cameraTrack: firstCameraTrack,
                microphoneTrack: firstMicrophoneTrack,
              ),
            );
            await controller.initializationStarted.future;

            check(controller.room).isNull();
            check(
              controller.state.connectionState,
            ).equals(RoomConnectionState.connecting);

            final secondCameraTrack = MockLocalVideoTrack();
            final secondMicrophoneTrack = MockLocalAudioTrack();
            var firstCompleted = false;
            unawaited(firstJoin.then((_) => firstCompleted = true));
            var secondCompleted = false;
            final duplicateMicrotasks = Queue<void Function()>();
            var holdDuplicateMicrotasks = true;
            late Future<SessionJoinResult> secondResult;
            runZoned(
              () {
                secondResult = controller.join(
                  joinMedia: SessionJoinMedia(
                    cameraTrack: secondCameraTrack,
                    microphoneTrack: secondMicrophoneTrack,
                  ),
                );
                unawaited(secondResult.then((_) => secondCompleted = true));
              },
              zoneSpecification: ZoneSpecification(
                scheduleMicrotask: (self, parent, zone, callback) {
                  if (holdDuplicateMicrotasks) {
                    duplicateMicrotasks.add(() => zone.run(callback));
                  } else {
                    parent.scheduleMicrotask(zone, callback);
                  }
                },
              ),
            );
            // Drain all of the duplicate call's disposal work. A premature
            // success cannot hide behind additional queued microtasks.
            while (duplicateMicrotasks.isNotEmpty) {
              duplicateMicrotasks.removeFirst()();
            }
            check(firstCompleted).isFalse();
            check(secondCompleted).isFalse();
            verify(secondCameraTrack.stop).called(1);
            verify(secondCameraTrack.dispose).called(1);
            verify(secondMicrophoneTrack.stop).called(1);
            verify(secondMicrophoneTrack.dispose).called(1);
            check(controller.initializationCount).equals(1);
            check(room.connectCount).equals(0);
            verifyNever(firstCameraTrack.stop);
            verifyNever(firstCameraTrack.dispose);
            verifyNever(firstMicrophoneTrack.stop);
            verifyNever(firstMicrophoneTrack.dispose);
            holdDuplicateMicrotasks = false;
            controller.initializationGate.complete();
            final expected = initializationFails
                ? SessionJoinResult.retryableFailure
                : SessionJoinResult.success;
            check(await firstJoin).equals(expected);
            check(await secondResult).equals(expected);
            check(secondCompleted).isTrue();
            if (initializationFails) {
              check(
                controller.state.connectionState,
              ).not((state) => state.equals(RoomConnectionState.connected));
              check(room.connectCount).equals(0);
              verifyNever(
                () => localParticipant.publishVideoTrack(
                  firstCameraTrack,
                  publishOptions: SessionController.defaultVideoPublishOptions,
                ),
              );
              verifyNever(
                () => localParticipant.publishAudioTrack(firstMicrophoneTrack),
              );
              verify(firstCameraTrack.stop).called(1);
              verify(firstCameraTrack.dispose).called(1);
              verify(firstMicrophoneTrack.stop).called(1);
              verify(firstMicrophoneTrack.dispose).called(1);
            } else {
              check(
                controller.state.connectionState,
              ).equals(RoomConnectionState.connected);
              check(room.connectCount).equals(1);
              check(room.lastFastConnectOptions).isNull();
              verify(
                () => localParticipant.publishVideoTrack(
                  firstCameraTrack,
                  publishOptions: SessionController.defaultVideoPublishOptions,
                ),
              ).called(1);
              verify(
                () => localParticipant.publishAudioTrack(firstMicrophoneTrack),
              ).called(1);
              verifyNever(firstCameraTrack.stop);
              verifyNever(firstCameraTrack.dispose);
              verifyNever(firstMicrophoneTrack.stop);
              verifyNever(firstMicrophoneTrack.dispose);
            }
            await controller.leave();
            // Teardown cannot release the extra caller's already released tracks again.
            verifyNoMoreInteractions(secondCameraTrack);
            verifyNoMoreInteractions(secondMicrophoneTrack);
          },
        );
      }

      test(
        'joining an already connected session releases only the newly supplied media',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(
              any<bool>(),
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          ).thenAnswer((_) async => null);
          final room = _CountingRoom(localParticipant);
          controller.room = room;

          check(await controller.join()).equals(SessionJoinResult.success);
          check(
            controller.state.connectionState,
          ).equals(RoomConnectionState.connected);

          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();
          final result = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
            ),
          );

          check(result).equals(SessionJoinResult.success);
          check(room.connectCount).equals(1);
          verify(cameraTrack.stop).called(1);
          verify(cameraTrack.dispose).called(1);
          verify(microphoneTrack.stop).called(1);
          verify(microphoneTrack.dispose).called(1);

          await controller.disposeConnection();

          verifyNoMoreInteractions(cameraTrack);
          verifyNoMoreInteractions(microphoneTrack);
        },
      );

      for (final camera in [true, false]) {
        test(
          'join refuses success when ${camera ? 'camera' : 'microphone'} publication is not accepted',
          () async {
            final options = SessionOptions(
              sessionSlug: 'declined-publication',
              token: 'token',
              cameraEnabled: camera,
              microphoneEnabled: !camera,
              speakerEnabled: true,
              cameraOptions: SessionController.defaultCameraCaptureOptions,
            );
            final container = ProviderContainer(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
                sessionProvider(options.sessionSlug).overrideWithValue(
                  AsyncData(_createSessionEvent(options.sessionSlug)),
                ),
                roomStateProvider(options.sessionSlug).overrideWith(
                  (ref) =>
                      ref.read(sessionControllerProvider(options)).roomState,
                ),
              ],
            );
            final subscription = container.listen(
              sessionControllerProvider(options),
              (_, _) {},
            );
            final controller = container.read(
              sessionControllerProvider(options).notifier,
            );
            final participant = MockLocalParticipant();
            final room = _CountingRoom(participant);
            final cameraTrack = MockLocalVideoTrack();
            final microphoneTrack = MockLocalAudioTrack();
            controller.room = room;
            try {
              // Capture has been released while the connection/participant remain
              // available. The real adapter deliberately declines publication.
              await controller.localMedia.release();
              check(controller.localMedia.isAvailable).isTrue();
              check(
                await controller.join(
                  joinMedia: SessionJoinMedia(
                    cameraTrack: camera ? cameraTrack : null,
                    microphoneTrack: camera ? null : microphoneTrack,
                  ),
                ),
              ).equals(SessionJoinResult.retryableFailure);
              check(
                controller.state.connectionState,
              ).not((state) => state.equals(RoomConnectionState.connected));
              check(room.connectCount).equals(1);
              verifyNever(
                () => participant.publishVideoTrack(
                  cameraTrack,
                  publishOptions: SessionController.defaultVideoPublishOptions,
                ),
              );
              verifyNever(() => participant.publishAudioTrack(microphoneTrack));
              if (camera) {
                verify(cameraTrack.stop).called(1);
                verify(cameraTrack.dispose).called(1);
              } else {
                verify(microphoneTrack.stop).called(1);
                verify(microphoneTrack.dispose).called(1);
              }
            } finally {
              await controller.leave();
              subscription.close();
              container.dispose();
            }
          },
        );
      }

      test(
        'join releases transferred camera without publishing when disabled',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: false,
            microphoneEnabled: false,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final participant = MockLocalParticipant();
          final cameraTrack = MockLocalVideoTrack();
          when(
            () => participant.publishVideoTrack(
              cameraTrack,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          ).thenAnswer((_) async => MockLocalTrackPublication());
          when(
            () =>
                participant.setCameraEnabled(false, cameraCaptureOptions: null),
          ).thenAnswer((_) async => null);
          when(
            () => participant.setMicrophoneEnabled(
              false,
              audioCaptureOptions: any(named: 'audioCaptureOptions'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => participant.unpublishAllTracks(notify: true),
          ).thenAnswer((_) async {});
          when(
            () => participant.setTrackSubscriptionPermissions(
              allParticipantsAllowed: false,
              trackPermissions: any(named: 'trackPermissions'),
            ),
          ).thenAnswer((_) async {});
          final room = _CountingRoom(participant, emitConnectedOnConnect: true);
          controller.room = room;

          var previewDetached = false;
          final result = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              onBeforeDispose: () => previewDetached = true,
            ),
          );

          check(result).equals(SessionJoinResult.success);
          check(previewDetached).isTrue();
          check(room.lastFastConnectOptions).isNull();
          verifyNever(
            () => participant.publishVideoTrack(
              cameraTrack,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          );
          verifyNever(() => participant.setCameraEnabled(true));
          verify(cameraTrack.stop).called(1);
          verify(cameraTrack.dispose).called(1);
          await controller.disposeConnection();
          verifyNever(cameraTrack.stop);
          verifyNever(cameraTrack.dispose);
        },
      );

      test('join waits for transferred pre-join tracks to publish', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          sessionSlug: eventSlug,
          token: 'test-token',
          cameraEnabled: true,
          microphoneEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
          speakerEnabled: true,
        );

        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        final cameraTrack = MockLocalVideoTrack();
        final microphoneTrack = MockLocalAudioTrack();
        final cameraPublication =
            Completer<LocalTrackPublication<LocalVideoTrack>>();
        final microphonePublication =
            Completer<LocalTrackPublication<LocalAudioTrack>>();
        when(
          () => localParticipant.publishVideoTrack(
            cameraTrack,
            publishOptions: SessionController.defaultVideoPublishOptions,
          ),
        ).thenAnswer((_) => cameraPublication.future);
        when(
          () => localParticipant.publishAudioTrack(microphoneTrack),
        ).thenAnswer((_) => microphonePublication.future);

        final room = _CountingRoom(
          localParticipant,
          emitConnectedOnConnect: true,
        );
        controller.room = room;

        var joinCompleted = false;
        final joinResult = controller
            .join(
              joinMedia: SessionJoinMedia(
                cameraTrack: cameraTrack,
                microphoneTrack: microphoneTrack,
              ),
            )
            .then((result) {
              joinCompleted = true;
              return result;
            });
        await pumpEventQueue();

        check(joinCompleted).isFalse();
        check(
          container.read(sessionControllerProvider(options)).connection.state,
        ).equals(RoomConnectionState.connecting);
        check(room.lastFastConnectOptions).isNull();
        verify(
          () => localParticipant.publishVideoTrack(
            cameraTrack,
            publishOptions: SessionController.defaultVideoPublishOptions,
          ),
        ).called(1);
        verifyNever(() => localParticipant.publishAudioTrack(microphoneTrack));

        cameraPublication.complete(MockLocalTrackPublication());
        await pumpEventQueue();

        check(joinCompleted).isFalse();
        verify(
          () => localParticipant.publishAudioTrack(microphoneTrack),
        ).called(1);

        microphonePublication.complete(MockLocalAudioTrackPublication());
        check(await joinResult).equals(SessionJoinResult.success);
        check(
          container.read(sessionControllerProvider(options)).connection.state,
        ).equals(RoomConnectionState.connected);
        verifyNever(cameraTrack.stop);
        verifyNever(cameraTrack.dispose);
        verifyNever(microphoneTrack.stop);
        verifyNever(microphoneTrack.dispose);

        await controller.disposeConnection();

        check(room.disposeCount).equals(1);
        verifyNever(cameraTrack.stop);
        verifyNever(cameraTrack.dispose);
        verifyNever(microphoneTrack.stop);
        verifyNever(microphoneTrack.dispose);
      });

      test(
        'join stops publishing when disposed during video publication',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();
          final cameraPublication =
              Completer<LocalTrackPublication<LocalVideoTrack>>();
          final publicationStarted = Completer<void>();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.publishVideoTrack(
              cameraTrack,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          ).thenAnswer((_) {
            publicationStarted.complete();
            return cameraPublication.future;
          });

          final room = _CountingRoom(localParticipant);
          controller.room = room;
          final joinResult = controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
            ),
          );
          await publicationStarted.future;

          container.dispose();
          final disposal = controller.runtime.dispose();
          check(room.disposeCount).equals(0);
          verifyNever(cameraTrack.stop);
          verifyNever(microphoneTrack.stop);
          cameraPublication.complete(MockLocalTrackPublication());

          check(await joinResult).equals(SessionJoinResult.retryableFailure);
          await disposal;
          check(room.disposeCount).equals(1);
          verify(microphoneTrack.stop).called(1);
          verify(microphoneTrack.dispose).called(1);
          verifyNever(cameraTrack.stop);
          verifyNever(cameraTrack.dispose);
          verify(localParticipant.unpublishAllTracks).called(1);
          verifyNever(
            () => localParticipant.publishAudioTrack(microphoneTrack),
          );
        },
      );

      test(
        'leave during publication waits for ownership and skips the next track',
        () async {
          const options = SessionOptions(
            sessionSlug: 'test-session',
            token: 'token',
            cameraEnabled: true,
            microphoneEnabled: true,
            speakerEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
          );
          final container = _createContainerWithEventOverride(
            options.sessionSlug,
          );
          final subscription = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
          );
          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final participant = MockLocalParticipant();
          final camera = MockLocalVideoTrack();
          final microphone = MockLocalAudioTrack();
          final started = Completer<void>();
          final publication =
              Completer<LocalTrackPublication<LocalVideoTrack>>();
          var detached = false;
          when(
            () => participant.publishVideoTrack(
              camera,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          ).thenAnswer((_) {
            started.complete();
            return publication.future;
          });
          when(microphone.stop).thenAnswer((_) async {
            check(detached).isTrue();
            return true;
          });
          final room = _CountingRoom(participant);
          controller.room = room;
          final joining = controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: camera,
              microphoneTrack: microphone,
              onBeforeDispose: () => detached = true,
            ),
          );
          await started.future;
          var left = false;
          final leaving = controller.leave().then((_) => left = true);
          await Future<void>.value();
          check(left).isFalse();
          check(room.disconnectCount).equals(0);
          publication.complete(MockLocalTrackPublication());
          check(await joining).equals(SessionJoinResult.retryableFailure);
          await leaving;
          check(room.disconnectCount).equals(1);
          check(room.disposeCount).equals(1);
          verifyNever(() => participant.publishAudioTrack(microphone));
          verify(microphone.stop).called(1);
          verify(microphone.dispose).called(1);
          verifyNever(camera.stop);
          verifyNever(camera.dispose);
          verify(participant.unpublishAllTracks).called(1);
          subscription.close();
          container.dispose();
        },
      );

      test(
        'join keeps published media and cleans up a publication failure',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final localParticipant = MockLocalParticipant();
          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.publishVideoTrack(
              cameraTrack,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          ).thenAnswer((_) async => MockLocalTrackPublication());
          when(
            () => localParticipant.publishAudioTrack(microphoneTrack),
          ).thenThrow(TrackPublishException('microphone publication failed'));

          final room = _CountingRoom(localParticipant);
          controller.room = room;

          final result = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
            ),
          );

          check(result).equals(SessionJoinResult.retryableFailure);
          check(room.lastFastConnectOptions).isNull();
          verifyNever(cameraTrack.stop);
          verifyNever(cameraTrack.dispose);
          verify(microphoneTrack.stop).called(1);
          verify(microphoneTrack.dispose).called(1);
          verify(
            () => localParticipant.publishAudioTrack(microphoneTrack),
          ).called(1);

          await controller.resetAfterFailedJoin();

          expect(room.disposeCount, 1);
          expect(controller.room, isNull);
        },
      );

      test(
        'join disposes pre-join tracks before returning a setup failure',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();
          final localParticipant = MockLocalParticipant();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          final room = _CountingRoom(
            localParticipant,
            prepareConnectionError: StateError('prepare failed'),
          );
          controller.room = room;

          final joined = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
            ),
          );

          check(joined).equals(SessionJoinResult.retryableFailure);
          check(room.connectCount).equals(0);
          verify(cameraTrack.stop).called(1);
          verify(cameraTrack.dispose).called(1);
          verify(microphoneTrack.stop).called(1);
          verify(microphoneTrack.dispose).called(1);

          await controller.resetAfterFailedJoin();

          check(controller.room).isNull();
          verifyNoMoreInteractions(cameraTrack);
          verifyNoMoreInteractions(microphoneTrack);
        },
      );

      for (final testCase
          in <
            ({
              String name,
              ConnectException error,
              SessionJoinResult result,
              bool retryable,
            })
          >[
            (
              name: 'retryable connect timeout',
              error: ConnectException(
                'connect timed out',
                reason: ConnectionErrorReason.Timeout,
              ),
              result: SessionJoinResult.retryableFailure,
              retryable: true,
            ),
            (
              name: 'fatal connect failure',
              error: ConnectException(
                'connect forbidden',
                reason: ConnectionErrorReason.NotAllowed,
              ),
              result: SessionJoinResult.fatalFailure,
              retryable: false,
            ),
          ]) {
        test('join disposes tracks when ${testCase.name} throws', () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            sessionSlug: eventSlug,
            token: 'test-token',
            cameraEnabled: true,
            microphoneEnabled: true,
            cameraOptions: SessionController.defaultCameraCaptureOptions,
            speakerEnabled: true,
          );

          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );
          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();
          var previewAttached = true;
          when(cameraTrack.stop).thenAnswer((_) async {
            check(previewAttached).equals(false);
            return true;
          });
          final localParticipant = MockLocalParticipant();
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          final room = _CountingRoom(
            localParticipant,
            connectError: testCase.error,
          );
          controller.room = room;

          final result = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
              onBeforeDispose: () => previewAttached = false,
            ),
          );

          check(result).equals(testCase.result);
          check(previewAttached).isFalse();
          check(room.connectCount).equals(1);
          check(room.lastFastConnectOptions).isNull();
          verifyNever(
            () => localParticipant.publishVideoTrack(
              cameraTrack,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          );
          verifyNever(
            () => localParticipant.publishAudioTrack(microphoneTrack),
          );
          verify(cameraTrack.stop).called(1);
          verify(cameraTrack.dispose).called(1);
          verify(microphoneTrack.stop).called(1);
          verify(microphoneTrack.dispose).called(1);

          if (testCase.retryable) {
            await controller.resetAfterFailedJoin();
          } else {
            await controller.disposeConnection();
          }

          check(room.disposeCount).equals(1);
          verifyNoMoreInteractions(cameraTrack);
          verifyNoMoreInteractions(microphoneTrack);
        });
      }
    });

    group('Test-Visible Helpers', () {
      const eventSlug = 'test-session';
      const options = SessionOptions(
        sessionSlug: eventSlug,
        token: 'test-token',
        cameraEnabled: true,
        microphoneEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
        speakerEnabled: true,
      );

      test('sortedParticipants returns empty when room is null', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );

        check(controller.sortedParticipants()).isEmpty();
      });

      test(
        'resolveMetadataState returns null roomState for empty metadata',
        () {
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );

          final result = controller.resolveMetadataState(
            metadata: '',
            lastMetadata: 'previous-metadata',
          );

          check(result.roomState).isNull();
          check(result.lastMetadata).equals('previous-metadata');
        },
      );

      test('resolveMetadataState decodes and returns new roomState', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );

        const expected = RoomState(
          keeper: 'keeper-1',
          nextSpeaker: Omittable('next-speaker'),
          currentSpeaker: Omittable('current-speaker'),
          status: RoomStatus.waitingRoom,
          turnState: TurnState.idle,
          sessionSlug: eventSlug,
          statusDetail: RoomStateStatusDetailWaitingRoom(
            WaitingRoomDetail(type: 'waiting_room'),
          ),
          talkingOrder: ['current-speaker', 'next-speaker'],
          version: 7,
          roundNumber: 3,
        );
        final metadata = jsonEncode(expected.toJson());

        final result = controller.resolveMetadataState(
          metadata: metadata,
          lastMetadata: null,
        );

        check(result.roomState).equals(expected);
        check(result.lastMetadata).equals(metadata);
      });
    });

    group('Public State API', () {
      const eventSlug = 'test-session';
      const options = SessionOptions(
        sessionSlug: eventSlug,
        token: 'test-token',
        cameraEnabled: true,
        microphoneEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
        speakerEnabled: true,
      );

      test('addSessionChatMessage appends message', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final _ = container.read(sessionControllerProvider(options).notifier)
          ..addSessionChatMessage(
            const SessionChatMessage(
              message: 'hello',
              timestamp: 1,
              id: 'm1',
              sender: true,
            ),
          );

        final messages = container
            .read(sessionControllerProvider(options).notifier)
            .chat
            .messages;
        check(messages).length.equals(1);
        check(messages.first.message).equals('hello');
      });

      test('markParticipantRemoved updates removed flag', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final _ = container.read(sessionControllerProvider(options).notifier)
          ..markParticipantRemoved(RemoveReason.remove);

        final state = container.read(sessionControllerProvider(options));
        check(state.removed).equals(true);
      });

      test('applyRoomState updates roomState', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );

        const newRoomState = RoomState(
          keeper: 'keeper-2',
          nextSpeaker: Omittable('next'),
          currentSpeaker: Omittable('current'),
          status: RoomStatus.waitingRoom,
          turnState: TurnState.idle,
          sessionSlug: eventSlug,
          statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
          talkingOrder: ['current', 'next'],
          version: 2,
          roundNumber: 1,
        );

        controller.applyRoomState(newRoomState);

        final state = container.read(sessionControllerProvider(options));
        check(state.roomState).equals(newRoomState);
      });

      test(
        'disconnectFromRoom completes when no room is initialized',
        () async {
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);
          final sub = container.listen(
            sessionControllerProvider(options),
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          final controller = container.read(
            sessionControllerProvider(options).notifier,
          );

          await check(controller.disconnectFromRoom()).completes();
        },
      );
    });

    test(
      'default media settings preserve the native capture and codec budget',
      () {
        check(
          SessionController.syncTimerDuration,
        ).equals(const Duration(seconds: 20));
        final capture = SessionController.defaultCameraCaptureOptions.params;
        check(capture.dimensions).equals(VideoDimensionsPresets.h720_43);
        check(capture.encoding?.maxFramerate).equals(24);
        check(capture.encoding?.maxBitrate).equals(1300 * 1000);

        final publish = SessionController.defaultVideoPublishOptions;
        check(publish.videoCodec).equals('h265');
        check(publish.backupVideoCodec.enabled).isTrue();
        check(publish.backupVideoCodec.codec).equals('h264');
      },
    );
  });
}
