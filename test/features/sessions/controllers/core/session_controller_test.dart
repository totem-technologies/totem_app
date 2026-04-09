import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';

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

void main() {
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
            audioOutputOptions: AudioOutputOptions(speakerOn: true),
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
              defaultAudioOutputOptions: options.audioOutputOptions,
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
          audioOutputOptions: AudioOutputOptions(speakerOn: true),
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
            defaultAudioOutputOptions: options.audioOutputOptions,
          ),
          url: 'wss://example.livekit.cloud',
          token: options.token,
        );

        expect(controller.room, isNotNull);
        await controller.disposeConnection();
        expect(controller.room, isNull);
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
        audioOutputOptions: AudioOutputOptions(speakerOn: true),
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
        audioOutputOptions: AudioOutputOptions(speakerOn: true),
      );

      test('setKeeperDisconnected updates hasKeeperDisconnected', () {
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
        )..setKeeperDisconnected(true);

        final state = container.read(sessionControllerProvider(options));
        expect(state.hasKeeperDisconnected, isTrue);
      });

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
        )..markParticipantRemoved();

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

      test('defaultCameraCaptureOptions has 20 fps framerate', () {
        expect(
          SessionController
              .defaultCameraCaptureOptions
              .params
              .encoding
              ?.maxFramerate,
          equals(20),
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
    });
  });
}
