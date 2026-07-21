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
import 'package:totem_core/features/sessions/controllers/core/session_state_events.dart';

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
      eventProvider(eventSlug).overrideWithValue(
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
    Map<String, RemoteParticipant>? remoteParticipants,
  }) : _remoteParticipants = remoteParticipants ?? {};

  final MockLocalParticipant participant;
  final _CountingRoomEventsListener listener = _CountingRoomEventsListener();

  int prepareConnectionCount = 0;
  int connectCount = 0;
  int disconnectCount = 0;
  int disposeCount = 0;

  /// Override to inject remote participants for track health tests.
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(_remoteParticipants);

  final Map<String, RemoteParticipant> _remoteParticipants;
  @override
  LocalParticipant get localParticipant => participant;

  @override
  Future<void> prepareConnection(String url, String? token) async {
    prepareConnectionCount++;
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
            eventSlug: eventSlug,
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
          eventSlug: eventSlug,
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

      test(
        'transient join disconnect keeps room available for retry',
        () async {
          const eventSlug = 'test-session';
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          const options = SessionOptions(
            eventSlug: eventSlug,
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

      test('join only calls room.connect once while connecting', () async {
        const eventSlug = 'test-session';
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        const options = SessionOptions(
          eventSlug: eventSlug,
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
    });

    group('Test-Visible Helpers', () {
      const eventSlug = 'test-session';
      const options = SessionOptions(
        eventSlug: eventSlug,
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
        eventSlug: eventSlug,
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

    group('Track Health Monitoring', () {
      const eventSlug = 'test-session';
      const options = SessionOptions(
        eventSlug: eventSlug,
        token: 'test-token',
        cameraEnabled: true,
        microphoneEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
        speakerEnabled: true,
      );

      SessionController _makeController(
        ProviderContainer container, {
        Map<String, RemoteParticipant>? remoteParticipants,
      }) {
        final sub = container.listen(
          sessionControllerProvider(options),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final localParticipant = MockLocalParticipant();
        when(
          () => localParticipant.setCameraEnabled(any<bool>()),
        ).thenAnswer((_) async => null);
        when(
          () => localParticipant.setMicrophoneEnabled(any<bool>()),
        ).thenAnswer((_) async => null);

        final controller = container.read(
          sessionControllerProvider(options).notifier,
        );
        controller.room = _CountingRoom(
          localParticipant,
          remoteParticipants: remoteParticipants,
        );

        controller.dispatch(
          const ConnectionChanged(
            RoomConnectionState.connected,
            SessionPhase.connected,
          ),
        );

        controller.applyRoomState(
          const RoomState(
            keeper: '',
            nextSpeaker: '',
            currentSpeaker: '',
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

        return controller;
      }

      test('does nothing when room is null', () {
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

        expect(() => controller.monitorTrackHealth(), returnsNormally);
      });

      test('does nothing when no remote participants', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);
        final controller = _makeController(container);

        expect(() => controller.monitorTrackHealth(), returnsNormally);
      });

      test('does nothing when all audio tracks are subscribed', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        final track = MockRemoteAudioTrackPublication(
          sid: 'track-1',
          subscribed: true,
        );
        final p = MockRemoteParticipant(
          'p1',
          'P1',
          audioTracks: [track],
        );
        final controller = _makeController(
          container,
          remoteParticipants: {'p1': p},
        );

        controller.monitorTrackHealth();
        expect(track.subscribed, isTrue);
      });

      test(
        'recovers unsubscribed track when subscription is allowed',
        () async {
          final container = _createContainerWithEventOverride(eventSlug);
          addTearDown(container.dispose);

          final track = MockRemoteAudioTrackPublication(
            sid: 'track-1',
            subscribed: false,
            subscriptionAllowed: true,
          );
          final p = MockRemoteParticipant(
            'p1',
            'P1',
            audioTracks: [track],
          );
          final controller = _makeController(
            container,
            remoteParticipants: {'p1': p},
          );

          controller.monitorTrackHealth();
          await pumpEventQueue();
          expect(track.subscribed, isTrue);
        },
      );

      test('skips track when subscription is not allowed', () {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        final track = MockRemoteAudioTrackPublication(
          sid: 'track-1',
          subscribed: false,
          subscriptionAllowed: false,
        );
        final p = MockRemoteParticipant(
          'p1',
          'P1',
          audioTracks: [track],
        );
        final controller = _makeController(
          container,
          remoteParticipants: {'p1': p},
        );

        controller.monitorTrackHealth();
        expect(track.subscribed, isFalse);
      });

      test('handles mixed states across participants', () async {
        final container = _createContainerWithEventOverride(eventSlug);
        addTearDown(container.dispose);

        final ok = MockRemoteAudioTrackPublication(
          sid: 'track-ok',
          subscribed: true,
        );
        final broken = MockRemoteAudioTrackPublication(
          sid: 'track-broken',
          subscribed: false,
          subscriptionAllowed: true,
        );
        final denied = MockRemoteAudioTrackPublication(
          sid: 'track-denied',
          subscribed: false,
          subscriptionAllowed: false,
        );

        final p1 = MockRemoteParticipant('p1', 'Good', audioTracks: [ok]);
        final p2 = MockRemoteParticipant(
          'p2',
          'Mixed',
          audioTracks: [broken, denied],
        );

        final controller = _makeController(
          container,
          remoteParticipants: {'p1': p1, 'p2': p2},
        );

        controller.monitorTrackHealth();
        await pumpEventQueue();

        expect(ok.subscribed, isTrue);
        expect(broken.subscribed, isTrue);
        expect(denied.subscribed, isFalse);
      });

      test('recoverAudioSubscription calls subscribe', () async {
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

        final track = MockRemoteAudioTrackPublication(
          sid: 'track-1',
          subscribed: false,
          subscriptionAllowed: true,
        );

        await controller.recoverAudioSubscription(track, 'test-user');

        expect(track.subscribed, isTrue);
      });
    });
  });
}
