import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';

import '../../media/fake_local_media.dart';
import '../core/session_controller_mock.dart';

void main() {
  group('SessionDeviceController', () {
    late FakeSessionController session;
    late FakeLocalMedia media;
    late ProviderContainer container;

    setUp(() {
      session = FakeSessionController();
      media = session.mockLocalMedia;
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    SessionDeviceController controller() =>
        container.read(sessionDeviceControllerProvider(session).notifier);

    SessionDeviceState deviceState() =>
        container.read(sessionDeviceControllerProvider(session));

    test('enableMicrophone unmutes the microphone', () async {
      await controller().enableMicrophone();

      check(media.microphoneCommands).deepEquals([true]);
      check(deviceState().isMicrophoneEnabled).isTrue();
    });

    test('enableMicrophone does nothing if already enabled', () async {
      media.isMicrophoneEnabled = true;

      await controller().enableMicrophone();

      check(media.microphoneCommands).isEmpty();
    });

    test('disableMicrophone mutes the microphone', () async {
      media.isMicrophoneEnabled = true;

      await controller().disableMicrophone();

      check(media.microphoneCommands).deepEquals([false]);
      check(deviceState().isMicrophoneEnabled).isFalse();
    });

    test('disableMicrophone does nothing if already disabled', () async {
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
        unawaited(devices.enableCamera());
        unawaited(devices.disableCamera());
        unawaited(devices.enableCamera());

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
        unawaited(devices.enableCamera());
        unawaited(devices.disableCamera());

        check(media.cameraCommands).deepEquals([false]);
        command.complete();
        await request;

        check(media.cameraCommands).deepEquals([false]);
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

    test('resetSpeakerRoutingDefaults resets preferences', () {
      final devices = controller()..resetSpeakerRoutingDefaults();
      check(devices.userSpeakerPreference).equals(true);
    });

    test('disposed controller rejects late device listener setup', () async {
      final devices = controller();

      await devices.dispose();
      await devices.setupDeviceChangeListener();
    });
  });
}
