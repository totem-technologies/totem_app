import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

import '../../../../setup.dart';
import '../../livekit_mocks.dart';

SessionDetailSchema _createSessionEvent(String eventSlug) {
  return SessionDetailSchema(
    slug: eventSlug,
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

ProviderContainer _createContainerWithEventOverride(String eventSlug) {
  return ProviderContainer(
    overrides: [
      sessionProvider(eventSlug).overrideWithValue(
        AsyncData(_createSessionEvent(eventSlug)),
      ),
    ],
  );
}

class _CountingRoomEventsListener implements EventsListener<RoomEvent> {
  int onCount = 0;
  int cancelAllCount = 0;
  int disposeCount = 0;
  final Map<Type, List<FutureOr<void> Function(Object?)>> _listeners = {};

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
  });

  final MockLocalParticipant participant;
  final Error? prepareConnectionError;
  final LiveKitException? connectError;
  final _CountingRoomEventsListener listener = _CountingRoomEventsListener();

  int prepareConnectionCount = 0;
  int connectCount = 0;
  int disconnectCount = 0;
  int disposeCount = 0;
  FastConnectOptions? lastFastConnectOptions;

  @override
  LocalParticipant get localParticipant => participant;

  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(const {});

  @override
  String? get metadata => null;

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
  }

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = true}) =>
      listener;

  @override
  Future<void> disconnect() async {
    disconnectCount++;
  }

  @override
  Future<bool> dispose() async {
    disposeCount++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedInitializeSessionController extends SessionController {
  final initializationStarted = Completer<void>();
  final initializationGate = Completer<void>();
  late Room initializedRoom;
  int initializationCount = 0;

  @override
  Future<Room> initializeConnection({
    required RoomOptions roomOptions,
    required String url,
    required String token,
  }) async {
    initializationCount++;
    if (!initializationStarted.isCompleted) {
      initializationStarted.complete();
    }
    await initializationGate.future;
    room = initializedRoom;
    return initializedRoom;
  }
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

          expect(controller.room, isNotNull);
          expect(identical(controller.room, initializedRoom), isTrue);
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

        expect(controller.room, isNotNull);
        await controller.disposeConnection();
        expect(controller.room, isNull);
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
            .whenComplete(
              () => joinCompleted = true,
            );
        await pumpEventQueue();

        expect(joinCompleted, isFalse);
        verify(cameraTrack.stop).called(1);
        verify(cameraTrack.dispose).called(1);
        verify(microphoneTrack.stop).called(1);
        verify(microphoneTrack.dispose).called(1);

        cameraDisposalGate.complete();
        expect(await joinFuture, SessionJoinResult.retryableFailure);
        expect(joinCompleted, isTrue);

        await controller.leave();
        expect(controller.room, isNull);
        expect(room.disconnectCount, 1);
        expect(room.disposeCount, 1);
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
          when(() => localParticipant.setCameraEnabled(any<bool>())).thenAnswer(
            (_) async => null,
          );
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer(
            (_) async => null,
          );

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

          expect(controller.room, same(room));
          expect(room.disposeCount, 0);
          expect(room.disconnectCount, 0);
          expect(
            controller.state.connectionState,
            RoomConnectionState.disconnected,
          );
        },
      );

      test(
        'FastConnect remains the sole initial media enablement path',
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

          await room.listener.trigger(
            RoomConnectedEvent(room: room, metadata: null),
          );
          await pumpEventQueue();

          verifyNever(
            () => localParticipant.setCameraEnabled(any<bool>()),
          );
          verifyNever(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          );
        },
      );

      test(
        'applies a microphone restriction after FastConnect publishes',
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
          var microphoneEnabled = false;
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            localParticipant.isMicrophoneEnabled,
          ).thenAnswer((_) => microphoneEnabled);
          when(
            () => localParticipant.setMicrophoneEnabled(false),
          ).thenAnswer((_) async {
            microphoneEnabled = false;
            return null;
          });

          final room = _CountingRoom(localParticipant);
          controller.room = room;
          expect(await controller.join(), SessionJoinResult.success);

          controller.applyRoomState(
            const RoomState(
              keeper: 'keeper',
              nextSpeaker: '',
              currentSpeaker: 'another-participant',
              status: RoomStatus.active,
              turnState: TurnState.idle,
              sessionSlug: eventSlug,
              statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
              talkingOrder: [],
              version: 1,
              roundNumber: 1,
            ),
          );

          await room.listener.trigger(
            RoomConnectedEvent(room: room, metadata: null),
          );
          await pumpEventQueue();

          // RoomConnected can arrive before FastConnect has registered its
          // publication. Enforce the mute when publication completes without
          // ever issuing a second enable operation.
          microphoneEnabled = true;
          final publication = MockLocalTrackPublication();
          when(
            () => publication.source,
          ).thenReturn(TrackSource.microphone);
          await room.listener.trigger(
            LocalTrackPublishedEvent(
              participant: localParticipant,
              publication: publication,
            ),
          );
          await pumpEventQueue();

          verify(
            () => localParticipant.setMicrophoneEnabled(false),
          ).called(1);
          verifyNever(
            () => localParticipant.setMicrophoneEnabled(true),
          );
          verifyNever(
            () => localParticipant.setCameraEnabled(any<bool>()),
          );
        },
      );

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
        when(() => localParticipant.setCameraEnabled(any<bool>())).thenAnswer(
          (_) async => null,
        );
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer(
          (_) async => null,
        );

        final room = _CountingRoom(localParticipant);
        controller.room = room;

        await controller.join();
        await controller.join();
        await controller.join();
        await controller.join();

        expect(room.prepareConnectionCount, 1);
        expect(room.connectCount, 1);
      });

      test(
        'join is guarded while connecting before room initialization',
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
              sessionProvider(eventSlug).overrideWithValue(
                AsyncData(_createSessionEvent(eventSlug)),
              ),
              sessionControllerProvider(options).overrideWith(
                _DelayedInitializeSessionController.new,
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
              container.read(
                    sessionControllerProvider(options).notifier,
                  )
                  as _DelayedInitializeSessionController;
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
          final firstJoin = controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: firstCameraTrack,
              microphoneTrack: firstMicrophoneTrack,
            ),
          );
          await controller.initializationStarted.future;

          expect(controller.room, isNull);
          expect(
            controller.state.connectionState,
            RoomConnectionState.connecting,
          );

          final secondCameraTrack = MockLocalVideoTrack();
          final secondMicrophoneTrack = MockLocalAudioTrack();
          final secondResult = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: secondCameraTrack,
              microphoneTrack: secondMicrophoneTrack,
            ),
          );

          expect(secondResult, SessionJoinResult.success);
          expect(controller.initializationCount, 1);
          expect(room.connectCount, 0);
          verify(secondCameraTrack.stop).called(1);
          verify(secondCameraTrack.dispose).called(1);
          verify(secondMicrophoneTrack.stop).called(1);
          verify(secondMicrophoneTrack.dispose).called(1);

          controller.initializationGate.complete();
          expect(await firstJoin, SessionJoinResult.success);
          expect(room.connectCount, 1);
          expect(
            room.lastFastConnectOptions?.camera.track,
            same(firstCameraTrack),
          );
          expect(
            room.lastFastConnectOptions?.microphone.track,
            same(firstMicrophoneTrack),
          );
          verifyNever(firstCameraTrack.stop);
          verifyNever(firstCameraTrack.dispose);
          verifyNever(firstMicrophoneTrack.stop);
          verifyNever(firstMicrophoneTrack.dispose);
        },
      );

      test(
        'join disposes newly transferred media when already connecting',
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

          await controller.join();

          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();
          final result = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
            ),
          );

          expect(result, SessionJoinResult.success);
          expect(room.connectCount, 1);
          verify(cameraTrack.stop).called(1);
          verify(cameraTrack.dispose).called(1);
          verify(microphoneTrack.stop).called(1);
          verify(microphoneTrack.dispose).called(1);

          await controller.disposeConnection();

          verifyNoMoreInteractions(cameraTrack);
          verifyNoMoreInteractions(microphoneTrack);
        },
      );

      test(
        'join transfers pre-join tracks without waiting for publications',
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
          when(() => localParticipant.setCameraEnabled(any<bool>())).thenAnswer(
            (_) async => null,
          );
          when(
            () => localParticipant.setMicrophoneEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          final cameraTrack = MockLocalVideoTrack();
          final microphoneTrack = MockLocalAudioTrack();

          final room = _CountingRoom(localParticipant);
          controller.room = room;

          final joined = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
            ),
          );

          expect(joined, SessionJoinResult.success);
          expect(
            room.lastFastConnectOptions?.camera.track,
            same(cameraTrack),
          );
          expect(
            room.lastFastConnectOptions?.microphone.track,
            same(microphoneTrack),
          );
          verifyNever(cameraTrack.stop);
          verifyNever(cameraTrack.dispose);
          verifyNever(microphoneTrack.stop);
          verifyNever(microphoneTrack.dispose);
          expect(localParticipant.getTrackPublications(), isEmpty);

          await controller.disposeConnection();

          expect(room.disposeCount, 1);
          verifyNever(cameraTrack.stop);
          verifyNever(cameraTrack.dispose);
          verifyNever(microphoneTrack.stop);
          verifyNever(microphoneTrack.dispose);
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
          when(() => localParticipant.setCameraEnabled(any<bool>())).thenAnswer(
            (_) async => null,
          );
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

          expect(joined, SessionJoinResult.retryableFailure);
          expect(room.connectCount, 0);
          verify(cameraTrack.stop).called(1);
          verify(cameraTrack.dispose).called(1);
          verify(microphoneTrack.stop).called(1);
          verify(microphoneTrack.dispose).called(1);

          await controller.resetAfterFailedJoin();

          expect(controller.room, isNull);
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
        test(
          'join disposes tracks when ${testCase.name} throws',
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
            var previewAttached = true;
            when(cameraTrack.stop).thenAnswer((_) async {
              expect(previewAttached, isFalse);
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

            expect(result, testCase.result);
            expect(previewAttached, isFalse);
            expect(room.connectCount, 1);
            expect(
              room.lastFastConnectOptions?.camera.track,
              same(cameraTrack),
            );
            expect(
              room.lastFastConnectOptions?.microphone.track,
              same(microphoneTrack),
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

            expect(room.disposeCount, 1);
            verifyNoMoreInteractions(cameraTrack);
            verifyNoMoreInteractions(microphoneTrack);
          },
        );
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

        expect(controller.sortedParticipants(), isEmpty);
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

          expect(result.roomState, isNull);
          expect(result.lastMetadata, 'previous-metadata');
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
          nextSpeaker: 'next-speaker',
          currentSpeaker: 'current-speaker',
          status: RoomStatus.waitingRoom,
          turnState: TurnState.idle,
          sessionSlug: eventSlug,
          statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
          talkingOrder: ['current-speaker', 'next-speaker'],
          version: 7,
          roundNumber: 3,
        );
        final metadata = jsonEncode(expected.toJson());

        final result = controller.resolveMetadataState(
          metadata: metadata,
          lastMetadata: null,
        );

        expect(result.roomState, expected);
        expect(result.lastMetadata, metadata);
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

        final _ =
            container.read(
              sessionControllerProvider(options).notifier,
            )..addSessionChatMessage(
              const SessionChatMessage(
                message: 'hello',
                timestamp: 1,
                id: 'm1',
                sender: true,
              ),
            );

        final state = container.read(sessionControllerProvider(options));
        expect(state.messages, hasLength(1));
        expect(state.messages.first.message, 'hello');
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

        final _ = container.read(
          sessionControllerProvider(options).notifier,
        )..markParticipantRemoved(RemoveReason.remove);

        final state = container.read(sessionControllerProvider(options));
        expect(state.removed, isTrue);
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
          nextSpeaker: 'next',
          currentSpeaker: 'current',
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
        expect(state.roomState, newRoomState);
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

          await expectLater(controller.disconnectFromRoom(), completes);
        },
      );
    });

    group('Static Defaults', () {
      test('syncTimerDuration is 20 seconds', () {
        expect(
          SessionController.syncTimerDuration,
          equals(const Duration(seconds: 20)),
        );
      });

      test('syncTimerDuration is positive', () {
        expect(
          SessionController.syncTimerDuration.isNegative,
          isFalse,
        );
      });

      test('defaultCameraCaptureOptions is defined', () {
        expect(
          SessionController.defaultCameraCaptureOptions,
          isNotNull,
        );
      });

      test('defaultCameraCaptureOptions has h720_43 dimensions', () {
        expect(
          SessionController.defaultCameraCaptureOptions.params.dimensions,
          equals(VideoDimensionsPresets.h720_43),
        );
      });

      test('defaultCameraCaptureOptions has 24 fps framerate', () {
        expect(
          SessionController
              .defaultCameraCaptureOptions
              .params
              .encoding
              ?.maxFramerate,
          equals(24),
        );
      });

      test('defaultCameraCaptureOptions has 1300kbps bitrate', () {
        expect(
          SessionController
              .defaultCameraCaptureOptions
              .params
              .encoding
              ?.maxBitrate,
          equals(1300 * 1000),
        );
      });

      test('defaultVideoPublishOptions uses h265 codec on native', () {
        expect(
          SessionController.defaultVideoPublishOptions.videoCodec,
          equals('h265'),
        );
      });

      test(
        'defaultVideoPublishOptions configures h264 as backup video codec',
        () {
          final backup =
              SessionController.defaultVideoPublishOptions.backupVideoCodec;
          expect(backup.enabled, isTrue);
          expect(backup.codec, equals('h264'));
        },
      );
    });
  });
}
