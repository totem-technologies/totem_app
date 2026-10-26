import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/media_devices_provider.dart';

import '../../../../setup.dart';
import '../../../permissions/fake_media_permission_adapter.dart';
import '../../media/fake_local_media.dart';
import '../core/session_controller_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupAppConfig);
  silenceLogger();

  group('SessionDeviceController', () {
    late FakeSessionController session;
    late FakeLocalMedia media;
    late ProviderContainer container;

    setUp(() {
      session = FakeSessionController();
      media = session.mockLocalMedia;
      container = ProviderContainer(
        overrides: grantedMediaPermissionOverrides(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    SessionDeviceController controller() =>
        container.read(sessionDeviceControllerProvider(session).notifier);

    SessionDeviceState deviceState() =>
        container.read(sessionDeviceControllerProvider(session));

    test(
      'refreshes outputs after the browser grants an output device',
      () async {
        final catalog = FakeMediaDeviceCatalog([fakeAudioOutput('default')]);
        final devicesContainer = ProviderContainer(
          overrides: [mediaDeviceCatalogProvider.overrideWithValue(catalog)],
        );
        addTearDown(devicesContainer.dispose);
        final mediaDevicesSubscription = devicesContainer.listen(
          mediaDevicesProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(mediaDevicesSubscription.close);
        await devicesContainer.read(mediaDevicesProvider.future);
        catalog.current = [
          fakeAudioOutput('default'),
          fakeAudioOutput('headphones'),
        ];

        await devicesContainer
            .read(sessionDeviceControllerProvider(session).notifier)
            .requestAudioOutputDevice();

        check(await devicesContainer.read(mediaDevicesProvider.future))
            .has((devices) => devices.map((device) => device.id), 'ids')
            .deepEquals(['default', 'headphones']);
      },
    );

    test('turning the microphone on unmutes it', () async {
      await controller().turnOn(MediaKind.microphone);

      check(media.microphoneCommands).deepEquals([true]);
      check(deviceState().isMicrophoneEnabled).isTrue();
    });

    test('turning on a microphone that is on does nothing', () async {
      media.isMicrophoneEnabled = true;

      await controller().turnOn(MediaKind.microphone);

      check(media.microphoneCommands).isEmpty();
    });

    test('disableMicrophone mutes the microphone', () async {
      media.isMicrophoneEnabled = true;

      await controller().disableMicrophone();

      check(media.microphoneCommands).deepEquals([false]);
      check(deviceState().isMicrophoneEnabled).isFalse();
    });

    test('a turn-off is sent even while the device reads off', () async {
      // The join publishes on media's own queue, so a device can read off
      // while its publish is in flight. Media orders the turn-off after it.
      await controller().disableMicrophone();
      await controller().disableCamera();

      check(media.microphoneCommands).deepEquals([false]);
      check(media.cameraCommands).deepEquals([false]);
    });

    test('a turn-off with no room sends nothing', () async {
      media.isAvailable = false;

      await controller().disableMicrophone();

      check(media.microphoneCommands).isEmpty();
    });

    test('reflects media changes made outside the controller', () {
      media
        ..hasMicrophoneTrack = true
        ..isMicrophoneEnabled = true;
      controller();
      check(deviceState().isMicrophoneEnabled).isTrue();

      // A keeper mutes the participant from the server.
      media
        ..isMicrophoneEnabled = false
        ..emitChange();

      check(deviceState().isMicrophoneEnabled).isFalse();
    });

    test('controls show the join preference until tracks are published', () {
      session.mockOptions = const SessionOptions(
        sessionSlug: 'test-session',
        token: 'test-token',
        cameraEnabled: true,
        microphoneEnabled: true,
        speakerEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
      );
      controller();
      check(deviceState())
        ..has((s) => s.isMicrophoneOn, 'isMicrophoneOn').isTrue()
        ..has((s) => s.isCameraOn, 'isCameraOn').isTrue();

      // Both tracks publish muted.
      media
        ..hasMicrophoneTrack = true
        ..hasCameraTrack = true
        ..emitChange();

      check(deviceState())
        ..has((s) => s.isMicrophoneOn, 'isMicrophoneOn').isFalse()
        ..has((s) => s.isCameraOn, 'isCameraOn').isFalse();
    });

    test('the microphone shows off when joining muted as a listener', () {
      session
        ..mockOptions = const SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: true,
          speakerEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
        )
        // Someone else is speaking, so joining publishes no microphone.
        ..mockShouldEnableMicrophone = false;
      controller();

      check(deviceState().isMicrophoneOn).isFalse();
    });

    test('the microphone follows the session until it is published', () {
      session
        ..mockOptions = const SessionOptions(
          sessionSlug: 'test-session',
          token: 'test-token',
          cameraEnabled: false,
          microphoneEnabled: true,
          speakerEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
        )
        ..mockShouldEnableMicrophone = false;
      controller();
      check(deviceState().isMicrophoneOn).isFalse();

      // The participant receives the totem before their microphone publishes.
      session.mockShouldEnableMicrophone = true;
      controller().syncWithSession();

      check(deviceState().isMicrophoneOn).isTrue();
    });

    test('controls show off once a published track is removed', () {
      session.mockOptions = const SessionOptions(
        sessionSlug: 'test-session',
        token: 'test-token',
        cameraEnabled: true,
        microphoneEnabled: true,
        speakerEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
      );
      media
        ..hasMicrophoneTrack = true
        ..isMicrophoneEnabled = true
        ..hasCameraTrack = true
        ..isCameraEnabled = true;
      controller();

      // Both tracks are unpublished, for example by the server.
      media
        ..hasMicrophoneTrack = false
        ..isMicrophoneEnabled = false
        ..hasCameraTrack = false
        ..isCameraEnabled = false
        ..emitChange();

      check(deviceState())
        ..has((s) => s.isMicrophoneOn, 'isMicrophoneOn').isFalse()
        ..has((s) => s.isCameraOn, 'isCameraOn').isFalse();
    });

    test('disableCamera turns the camera off', () async {
      media.isCameraEnabled = true;

      await controller().disableCamera();

      check(media.cameraCommands).deepEquals([false]);
      check(deviceState().isCameraEnabled).isFalse();
    });

    test(
      'coalesces rapid camera requests to the latest enabled state',
      () async {
        media.isCameraEnabled = true;
        var activeCommands = 0;
        var maximumActiveCommands = 0;
        final commands = <Completer<void>>[];
        final secondCommandStarted = Completer<void>();
        media.onCameraCommand = (enabled) {
          activeCommands++;
          if (activeCommands > maximumActiveCommands) {
            maximumActiveCommands = activeCommands;
          }
          if (enabled) secondCommandStarted.complete();
          final command = Completer<void>();
          commands.add(command);
          return command.future.whenComplete(() => activeCommands--);
        };

        final devices = controller();
        final request = devices.disableCamera();
        unawaited(devices.turnOn(MediaKind.camera));
        unawaited(devices.disableCamera());
        unawaited(devices.turnOn(MediaKind.camera));

        check(media.cameraCommands).deepEquals([false]);
        check(maximumActiveCommands).equals(1);

        commands.single.complete();
        await secondCommandStarted.future;

        check(media.cameraCommands).deepEquals([false, true]);
        check(maximumActiveCommands).equals(1);

        commands.last.complete();
        await request;

        check(media.isCameraEnabled).isTrue();
      },
    );

    test(
      'drops stale camera requests when the latest state is disabled',
      () async {
        media.isCameraEnabled = true;
        final command = Completer<void>();
        media.onCameraCommand = (_) => command.future;

        final devices = controller();
        final request = devices.disableCamera();
        unawaited(devices.turnOn(MediaKind.camera));
        unawaited(devices.disableCamera());

        check(media.cameraCommands).deepEquals([false]);
        command.complete();
        await request;
        await pumpEventQueue();

        // The stale turn-on is never sent; the latest turn-off is.
        check(media.cameraCommands).deepEquals([false, false]);
        check(media.isCameraEnabled).isFalse();
      },
    );

    test('recovers after a camera command fails', () async {
      media.isCameraEnabled = true;
      var shouldFail = true;
      media.onCameraCommand = (_) async {
        if (shouldFail) {
          shouldFail = false;
          throw StateError('camera unavailable');
        }
      };

      await controller().disableCamera();
      await controller().disableCamera();

      check(media.cameraCommands).deepEquals([false, false]);
      check(media.isCameraEnabled).isFalse();
    });

    test('selecting a camera updates the selected device', () async {
      await controller().selectCameraDevice(fakeCamera('camera-2', 'Rear'));

      check(deviceState().selectedCameraDeviceId).equals('camera-2');
    });

    test('selecting a camera is ignored without a room', () async {
      media.isAvailable = false;

      await controller().selectCameraDevice(fakeCamera('camera-2'));

      check(deviceState().selectedCameraDeviceId).isNull();
    });

    test('switching cameras reports the new facing', () async {
      media
        ..isCameraEnabled = true
        ..cameraFacing = CameraFacing.front;

      await controller().switchCameraPosition();

      check(deviceState().cameraFacing).equals(CameraFacing.back);
    });

    test(
      'sets the requested camera facing when the current facing is unknown',
      () async {
        media.isCameraEnabled = true;

        await controller().setCameraFacing(CameraFacing.back);

        check(deviceState().cameraFacing).equals(CameraFacing.back);
      },
    );

    test(
      'choosing the speaker routes audio and becomes the preference',
      () async {
        final devices = controller();

        await devices.setSpeakerphone(false);

        check(media.isSpeakerOutputPreferred).isFalse();
        check(devices.userSpeakerPreference).isFalse();
      },
    );

    test('joining a session replaces an earlier speaker choice', () async {
      final devices = controller();
      await devices.setSpeakerphone(false);

      devices.resetSpeakerRoutingDefaults();

      check(devices.userSpeakerPreference).isTrue();
    });
  });

  group('SessionDeviceController access', () {
    late FakeSessionController session;
    late FakeLocalMedia media;
    late ProviderContainer container;
    late FakeMediaPermissionAdapter adapter;

    setUp(() {
      session = FakeSessionController();
      media = session.mockLocalMedia;
      adapter = FakeMediaPermissionAdapter();
      container =
          ProviderContainer(
              overrides: [
                platformInfoProvider.overrideWithValue(
                  const WebPlatform(
                    browser: WebBrowser.chrome,
                    os: HostOs.macos,
                  ),
                ),
                mediaPermissionAdapterProvider.overrideWithValue(adapter),
              ],
            )
            // The session keeps its device controller alive; so does this.
            ..listen(sessionDeviceControllerProvider(session), (_, _) {});
    });

    tearDown(() => container.dispose());

    SessionDeviceController controller() =>
        container.read(sessionDeviceControllerProvider(session).notifier);

    MediaPermission? permission(MediaKind kind) {
      final MediaPermissions? state = container.read(
        mediaPermissionControllerProvider,
      );
      return state?[kind];
    }

    SessionDeviceState devices() =>
        container.read(sessionDeviceControllerProvider(session));

    test('X13: a microphone lost mid-call is reported and shown off', () async {
      media.isMicrophoneEnabled = true;
      final stopped = <MediaKind>[];
      controller().deviceNeedsAttention.listen(stopped.add);
      await container
          .read(mediaPermissionControllerProvider.notifier)
          .refresh();

      media.loseCapture(MediaKind.microphone);
      await pumpEventQueue();

      check(stopped).deepEquals([MediaKind.microphone]);
      check(devices().microphoneProblem).equals(DeviceProblem.lost);
      check(devices().isMicrophoneOn).isFalse();
      // A loss isn't a refusal; the permission says what it says.
      check(permission(MediaKind.microphone)).equals(MediaPermission.granted);
    });

    test('X13: a revoked permission follows the query', () async {
      media.isCameraEnabled = true;
      controller();
      await container
          .read(mediaPermissionControllerProvider.notifier)
          .refresh();

      adapter.queries[MediaKind.camera] = MediaPermission.blocked;
      media.loseCapture(MediaKind.camera);
      await pumpEventQueue();

      check(permission(MediaKind.camera)).equals(MediaPermission.blocked);
      check(devices().cameraProblem).equals(DeviceProblem.lost);
    });

    test('a device lost while off is not announced', () async {
      final stopped = <MediaKind>[];
      controller().deviceNeedsAttention.listen(stopped.add);

      media.loseCapture(MediaKind.microphone);
      await pumpEventQueue();

      check(stopped).isEmpty();
    });

    test('X13: a refused unmute is recorded, not thrown', () async {
      media.onMicrophoneCommand = (enabled) async {
        if (enabled) throw Exception('NotAllowedError: Permission denied');
      };

      await controller().turnOn(MediaKind.microphone);

      check(permission(MediaKind.microphone)).equals(MediaPermission.blocked);
      check(devices().isMicrophoneOn).isFalse();
    });

    test('X13: turning a lost device on again clears its problem', () async {
      media.isMicrophoneEnabled = true;
      controller();
      media.loseCapture(MediaKind.microphone);
      await pumpEventQueue();
      check(devices().microphoneProblem).equals(DeviceProblem.lost);

      final outcome = await controller().turnOn(MediaKind.microphone);

      check(outcome).isA<TurnedOn>();
      check(devices().microphoneProblem).isNull();
      check(devices().isMicrophoneOn).isTrue();
    });

    test('a keeper mute is not undone by the next action', () async {
      media.isMicrophoneEnabled = true;
      controller();
      // The keeper mutes the participant outside this controller.
      media
        ..isMicrophoneEnabled = false
        ..emitChange();

      await controller().turnOn(MediaKind.camera);

      check(media.microphoneCommands).isEmpty();
      check(media.cameraCommands).deepEquals([true]);
    });

    test(
      "X14: a track the room can't take is announced, not a problem",
      () async {
        await container
            .read(mediaPermissionControllerProvider.notifier)
            .refresh();
        adapter.queries[MediaKind.microphone] = MediaPermission.unknown;
        await container
            .read(mediaPermissionControllerProvider.notifier)
            .refresh();
        final blocked = <(MediaKind, TurnOnBlocker)>[];
        controller().turnOnBlocked.listen(blocked.add);
        media.onMicrophoneCommand = (_) async =>
            throw MediaPublishException(TimeoutException('publish'));

        final outcome = await controller().turnOn(MediaKind.microphone);
        await pumpEventQueue();

        check(outcome).isA<TurnOnSkipped>();
        check(
          blocked,
        ).deepEquals([(MediaKind.microphone, TurnOnBlocker.connection)]);
        check(devices().microphoneProblem).isNull();
        // The microphone was captured, so its permission is known (WS1).
        check(permission(MediaKind.microphone)).equals(MediaPermission.granted);
      },
    );

    test('a capture failure is returned and shown', () async {
      media.onCameraCommand = (_) async => throw Exception('NotReadableError');

      final outcome = await controller().turnOn(MediaKind.camera);

      check(
        outcome,
      ).equals(const TurnOnFailed(DeviceFailed(DeviceProblem.inUse)));
      check(devices().cameraProblem).equals(DeviceProblem.inUse);
    });

    test('turning a device off while it starts drops its failure', () async {
      final failing = Completer<void>();
      media.onCameraCommand = (enabled) =>
          enabled ? failing.future : Future<void>.value();

      final turningOn = controller().turnOn(MediaKind.camera);
      await pumpEventQueue();
      final turningOff = controller().disableCamera();
      failing.completeError(Exception('NotReadableError'));
      final outcome = await turningOn;
      await turningOff;

      check(outcome).isA<TurnOnSkipped>();
      check(devices().cameraProblem).isNull();
    });

    test('a publish failure after a newer turn-off says nothing', () async {
      final blocked = <(MediaKind, TurnOnBlocker)>[];
      controller().turnOnBlocked.listen(blocked.add);
      final publishing = Completer<void>();
      media.onCameraCommand = (enabled) =>
          enabled ? publishing.future : Future<void>.value();

      final turningOn = controller().turnOn(MediaKind.camera);
      await pumpEventQueue();
      final turningOff = controller().disableCamera();
      publishing.completeError(
        MediaPublishException(TimeoutException('publish')),
      );
      final outcome = await turningOn;
      await turningOff;
      await pumpEventQueue();

      check(outcome).isA<TurnOnSkipped>();
      check(blocked).isEmpty();
    });

    test('X14: turning a device on with no room says so', () async {
      final blocked = <(MediaKind, TurnOnBlocker)>[];
      controller().turnOnBlocked.listen(blocked.add);
      media.isAvailable = false;

      final outcome = await controller().turnOn(MediaKind.camera);
      await pumpEventQueue();

      check(outcome).isA<TurnOnSkipped>();
      check(media.cameraCommands).isEmpty();
      check(blocked).deepEquals([(MediaKind.camera, TurnOnBlocker.connection)]);
    });

    test('a device found on clears its old problem', () async {
      media
        ..hasCameraTrack = true
        ..isCameraEnabled = true;
      controller();
      media
        ..onCameraSwitch = (() async => throw Exception('NotFoundError'))
        ..onCameraCommand = (_) async => throw Exception('still stuck');
      await controller().switchCameraPosition();
      check(devices().cameraProblem).equals(DeviceProblem.notFound);
      // Turning it off failed too, so it still reads as on.
      check(devices().isCameraOn).isTrue();

      final outcome = await controller().turnOn(MediaKind.camera);

      check(outcome).isA<TurnedOn>();
      check(devices().cameraProblem).isNull();
    });

    test('nobody can unmute while the keeper is away', () async {
      final state = session.mockState;
      session.mockState = SessionRoomState(
        connection: state.connection,
        participants: ParticipantsState(
          participants: [
            for (final participant in state.participantsList)
              if (participant.identity != state.roomState.keeper) participant,
          ],
        ),
        chat: state.chat,
        turn: SessionTurnState(
          roomState: state.roomState.copyWith(status: RoomStatus.active),
        ),
      );

      final blocked = <(MediaKind, TurnOnBlocker)>[];
      controller().turnOnBlocked.listen(blocked.add);

      await controller().turnOn(MediaKind.microphone);
      await pumpEventQueue();

      check(media.microphoneCommands).isEmpty();
      check(
        blocked,
      ).deepEquals([(MediaKind.microphone, TurnOnBlocker.keeperAway)]);
    });

    test('X9: a camera switch that fails is recorded and shown', () async {
      media.isCameraEnabled = true;
      controller();
      media.onCameraSwitch = () async => throw Exception('NotFoundError');

      final flagged = <MediaKind>[];
      controller().deviceNeedsAttention.listen(flagged.add);

      await controller().switchCameraPosition();
      await pumpEventQueue();

      check(devices().cameraProblem).equals(DeviceProblem.notFound);
      check(devices().isCameraOn).isFalse();
      check(flagged).deepEquals([MediaKind.camera]);
    });

    test('a newer turn-on replaces a failing one', () async {
      final first = Completer<void>();
      var commands = 0;
      media.onCameraCommand = (_) {
        commands++;
        return commands == 1
            ? first.future
            : Future<void>.error(Exception('NotReadableError'));
      };

      final firstTurnOn = controller().turnOn(MediaKind.camera);
      await pumpEventQueue();
      final secondTurnOn = controller().turnOn(MediaKind.camera);
      first.completeError(Exception('NotFoundError'));

      check(await firstTurnOn).isA<TurnOnSkipped>();
      check(
        await secondTurnOn,
      ).equals(const TurnOnFailed(DeviceFailed(DeviceProblem.inUse)));
      check(devices().cameraProblem).equals(DeviceProblem.inUse);
    });

    test('a turn-on the released room ignores is not a success', () async {
      await container
          .read(mediaPermissionControllerProvider.notifier)
          .refresh();
      adapter.queries[MediaKind.camera] = MediaPermission.unknown;
      await container
          .read(mediaPermissionControllerProvider.notifier)
          .refresh();
      final blocked = <(MediaKind, TurnOnBlocker)>[];
      controller().turnOnBlocked.listen(blocked.add);
      media.appliesCommands = false;

      final outcome = await controller().turnOn(MediaKind.camera);
      await pumpEventQueue();

      check(outcome).isA<TurnOnSkipped>();
      check(blocked).deepEquals([(MediaKind.camera, TurnOnBlocker.connection)]);
      check(permission(MediaKind.camera)).equals(MediaPermission.unknown);
    });

    test('a successful unmute records the microphone as granted', () async {
      await container
          .read(mediaPermissionControllerProvider.notifier)
          .refresh();
      adapter.queries[MediaKind.microphone] = MediaPermission.unknown;

      await controller().turnOn(MediaKind.microphone);

      check(permission(MediaKind.microphone)).equals(MediaPermission.granted);
    });
  });
}
