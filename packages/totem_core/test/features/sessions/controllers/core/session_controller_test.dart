import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';

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
      sessionProvider(
        eventSlug,
      ).overrideWithValue(AsyncData(_createSessionEvent(eventSlug))),
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

          check(controller.room).isNotNull();
          check(identical(controller.room, initializedRoom)).equals(true);
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
          var microphoneEnabled = false;
          when(
            () => localParticipant.setCameraEnabled(any<bool>()),
          ).thenAnswer((_) async => null);
          when(
            localParticipant.isMicrophoneEnabled,
          ).thenAnswer((_) => microphoneEnabled);
          when(
            () => localParticipant.publishVideoTrack(
              cameraTrack,
              publishOptions: SessionController.defaultVideoPublishOptions,
            ),
          ).thenAnswer((_) async => MockLocalTrackPublication());
          when(
            () => localParticipant.publishAudioTrack(microphoneTrack),
          ).thenAnswer((_) async {
            microphoneEnabled = true;
            return MockLocalAudioTrackPublication();
          });
          when(() => localParticipant.setMicrophoneEnabled(false)).thenAnswer((
            _,
          ) async {
            microphoneEnabled = false;
            return null;
          });

          final room = _CountingRoom(localParticipant);
          controller
            ..room = room
            ..applyRoomState(
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
          verify(() => localParticipant.setMicrophoneEnabled(false)).called(1);
          verifyNever(() => localParticipant.setMicrophoneEnabled(true));
          verifyNever(() => localParticipant.setCameraEnabled(any<bool>()));
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
          final secondResult = await controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: secondCameraTrack,
              microphoneTrack: secondMicrophoneTrack,
            ),
          );

          check(secondResult).equals(SessionJoinResult.success);
          check(controller.initializationCount).equals(1);
          check(room.connectCount).equals(0);
          verify(secondCameraTrack.stop).called(1);
          verify(secondCameraTrack.dispose).called(1);
          verify(secondMicrophoneTrack.stop).called(1);
          verify(secondMicrophoneTrack.dispose).called(1);

          controller.initializationGate.complete();
          check(await firstJoin).equals(SessionJoinResult.success);
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

        final room = _CountingRoom(localParticipant);
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
          ).thenAnswer((_) => cameraPublication.future);

          final room = _CountingRoom(localParticipant);
          controller.room = room;
          final joinResult = controller.join(
            joinMedia: SessionJoinMedia(
              cameraTrack: cameraTrack,
              microphoneTrack: microphoneTrack,
            ),
          );
          await pumpEventQueue();

          container.dispose();
          await pumpEventQueue();
          cameraPublication.complete(MockLocalTrackPublication());

          expect(await joinResult, SessionJoinResult.retryableFailure);
          verifyNever(
            () => localParticipant.publishAudioTrack(microphoneTrack),
          );
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

        final state = container.read(sessionControllerProvider(options));
        check(state.messages).length.equals(1);
        check(state.messages.first.message).equals('hello');
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
        check(state.roomState).equals(newRoomState);
      });

      test('applyRoomState clears a share time reminder when passing', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final controller =
            container.read(sessionControllerProvider(options).notifier)
              ..applyRoomState(
                const RoomState(
                  keeper: 'keeper-1',
                  nextSpeaker: 'user-2',
                  currentSpeaker: 'user-1',
                  status: RoomStatus.active,
                  turnState: TurnState.idle,
                  sessionSlug: eventSlug,
                  statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
                  talkingOrder: ['user-1', 'user-2'],
                  version: 1,
                  roundNumber: 1,
                ),
              )
              ..room = FakeRoom(MockLocalParticipant('user-1'));
        final reminderProvider = sessionMessagingControllerProvider(controller);
        container
            .read(reminderProvider.notifier)
            .handleDataReceived(
              DataReceivedEvent(
                data: utf8.encode(jsonEncode({'elapsedMilliseconds': 120000})),
                participant: MockRemoteParticipant('keeper-1', 'Keeper'),
                topic: SessionCommunicationTopics.shareTimeReminder.topic,
              ),
            );
        check(container.read(reminderProvider)).isNotNull();

        final _ = container.read(sessionControllerProvider(options).notifier)
          ..room = null
          ..applyRoomState(
            const RoomState(
              keeper: 'keeper-1',
              nextSpeaker: 'user-2',
              currentSpeaker: 'user-1',
              status: RoomStatus.active,
              turnState: TurnState.passing,
              sessionSlug: eventSlug,
              statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
              talkingOrder: ['user-1', 'user-2'],
              version: 2,
              roundNumber: 1,
            ),
          );

        check(container.read(reminderProvider)).isNull();
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

    group('Static Defaults', () {
      test('syncTimerDuration is 20 seconds', () {
        check(
          SessionController.syncTimerDuration,
        ).equals(const Duration(seconds: 20));
      });

      test('syncTimerDuration is positive', () {
        check(SessionController.syncTimerDuration.isNegative).equals(false);
      });

      test('defaultCameraCaptureOptions is defined', () {
        check(SessionController.defaultCameraCaptureOptions).isNotNull();
      });

      test('defaultCameraCaptureOptions has h720_43 dimensions', () {
        check(
          SessionController.defaultCameraCaptureOptions.params.dimensions,
        ).equals(VideoDimensionsPresets.h720_43);
      });

      test('defaultCameraCaptureOptions has 24 fps framerate', () {
        check(
          SessionController
              .defaultCameraCaptureOptions
              .params
              .encoding
              ?.maxFramerate,
        ).equals(24);
      });

      test('defaultCameraCaptureOptions has 1300kbps bitrate', () {
        check(
          SessionController
              .defaultCameraCaptureOptions
              .params
              .encoding
              ?.maxBitrate,
        ).equals(1300 * 1000);
      });

      test('defaultVideoPublishOptions uses h265 codec on native', () {
        check(
          SessionController.defaultVideoPublishOptions.videoCodec,
        ).equals('h265');
      });

      test(
        'defaultVideoPublishOptions configures h264 as backup video codec',
        () {
          final backup =
              SessionController.defaultVideoPublishOptions.backupVideoCodec;
          check(backup.enabled).equals(true);
          check(backup.codec).equals('h264');
        },
      );
    });
  });
}
