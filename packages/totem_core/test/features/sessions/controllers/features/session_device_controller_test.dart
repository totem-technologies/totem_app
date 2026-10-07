import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide TimeoutException;
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';

import '../../../../setup.dart';
import '../../livekit_mocks.dart';
import '../core/session_controller_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCameraCaptureOptions());
    setupAppConfig();
  });

  group('SessionDeviceController', () {
    group('Device Controls', () {
      late FakeSessionController mockSession;
      late FakeRoom mockRoom;
      late MockLocalParticipant mockLocalParticipant;
      late ProviderContainer container;

      setUp(() {
        mockSession = FakeSessionController();
        mockLocalParticipant = MockLocalParticipant();
        mockRoom = FakeRoom(mockLocalParticipant);
        AudioManager.instance.setSpeakerOutputPreferred(true);

        mockSession.mockRoom = mockRoom;

        when(
          () => mockLocalParticipant.isMicrophoneEnabled(),
        ).thenReturn(false);
        when(
          () => mockLocalParticipant.setMicrophoneEnabled(any()),
        ).thenAnswer((_) async => null);

        when(() => mockLocalParticipant.isCameraEnabled()).thenReturn(false);
        when(
          () => mockLocalParticipant.setCameraEnabled(
            any(),
            cameraCaptureOptions: any(named: 'cameraCaptureOptions'),
          ),
        ).thenAnswer((_) async => null);

        container = ProviderContainer();
      });

      tearDown(() {
        container.dispose();
      });

      test(
        'enableMicrophone calls setMicrophoneEnabled on localParticipant',
        () async {
          final controller = container.read(
            sessionDeviceControllerProvider(mockSession).notifier,
          );

          await controller.enableMicrophone();

          verify(
            () => mockLocalParticipant.setMicrophoneEnabled(true),
          ).called(1);
        },
      );

      test('enableMicrophone reports whether the microphone is on', () async {
        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        );

        check(await controller.enableMicrophone()).isTrue();
      });

      test(
        'enableMicrophone reports false while the keeper is away mid-session',
        () async {
          mockSession.mockState = createTestSessionState(
            roomStatus: RoomStatus.active,
            keeperPresent: false,
          );
          final controller = container.read(
            sessionDeviceControllerProvider(mockSession).notifier,
          );

          check(await controller.enableMicrophone()).isFalse();
          verifyNever(() => mockLocalParticipant.setMicrophoneEnabled(any()));
        },
      );

      test('enableMicrophone surfaces capture failures', () async {
        when(
          () => mockLocalParticipant.setMicrophoneEnabled(true),
        ).thenThrow(Exception('Audio engine returned error code: -9001'));
        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        );

        await check(controller.enableMicrophone()).throws<Exception>();
      });

      test('enableMicrophone gives up on a capture that never finishes', () {
        fakeAsync((async) {
          when(
            () => mockLocalParticipant.setMicrophoneEnabled(true),
          ).thenAnswer((_) => Completer<LocalTrackPublication?>().future);
          final controller = container.read(
            sessionDeviceControllerProvider(mockSession).notifier,
          );

          Object? error;
          controller.enableMicrophone().catchError((Object e) {
            error = e;
            return false;
          });
          async.elapse(SessionDeviceController.microphoneEnableTimeout);

          check(error).isA<TimeoutException>();
        });
      });

      test('enableMicrophone does nothing if already enabled', () async {
        when(() => mockLocalParticipant.isMicrophoneEnabled()).thenReturn(true);
        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        );

        await controller.enableMicrophone();

        verifyNever(() => mockLocalParticipant.setMicrophoneEnabled(any()));
      });

      test(
        'disableMicrophone calls setMicrophoneEnabled(false) on localParticipant',
        () async {
          when(
            () => mockLocalParticipant.isMicrophoneEnabled(),
          ).thenReturn(true);
          final controller = container.read(
            sessionDeviceControllerProvider(mockSession).notifier,
          );

          await controller.disableMicrophone();

          verify(
            () => mockLocalParticipant.setMicrophoneEnabled(false),
          ).called(1);
        },
      );

      test('disableMicrophone does nothing if already disabled', () async {
        when(
          () => mockLocalParticipant.isMicrophoneEnabled(),
        ).thenReturn(false);
        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        );

        await controller.disableMicrophone();

        verifyNever(() => mockLocalParticipant.setMicrophoneEnabled(any()));
      });

      test(
        'disableCamera calls setCameraEnabled(false) on localParticipant',
        () async {
          when(() => mockLocalParticipant.isCameraEnabled()).thenReturn(true);
          final controller = container.read(
            sessionDeviceControllerProvider(mockSession).notifier,
          );

          await controller.disableCamera();

          verify(() => mockLocalParticipant.setCameraEnabled(false)).called(1);
        },
      );

      test(
        'coalesces rapid camera requests to the latest enabled state',
        () async {
          var cameraEnabled = true;
          var activeMutations = 0;
          var maximumActiveMutations = 0;
          final calls = <bool>[];
          final mutations = <Completer<void>>[];
          final secondMutationStarted = Completer<void>();

          when(
            () => mockLocalParticipant.isCameraEnabled(),
          ).thenAnswer((_) => cameraEnabled);
          when(() => mockLocalParticipant.setCameraEnabled(false)).thenAnswer((
            _,
          ) {
            calls.add(false);
            activeMutations++;
            if (activeMutations > maximumActiveMutations) {
              maximumActiveMutations = activeMutations;
            }
            final mutation = Completer<void>();
            mutations.add(mutation);
            return mutation.future.then<LocalTrackPublication<LocalTrack>?>((
              _,
            ) {
              cameraEnabled = false;
              activeMutations--;
              return null;
            });
          });
          when(
            () => mockLocalParticipant.setCameraEnabled(
              true,
              cameraCaptureOptions: any(named: 'cameraCaptureOptions'),
            ),
          ).thenAnswer((_) {
            calls.add(true);
            activeMutations++;
            if (activeMutations > maximumActiveMutations) {
              maximumActiveMutations = activeMutations;
            }
            secondMutationStarted.complete();
            final mutation = Completer<void>();
            mutations.add(mutation);
            return mutation.future.then<LocalTrackPublication<LocalTrack>?>((
              _,
            ) {
              cameraEnabled = true;
              activeMutations--;
              return null;
            });
          });

          final controller = container.read(
            sessionDeviceControllerProvider(mockSession).notifier,
          );
          final request = controller.disableCamera();
          unawaited(controller.enableCamera());
          unawaited(controller.disableCamera());
          unawaited(controller.enableCamera());

          check(calls).deepEquals([false]);
          check(maximumActiveMutations).equals(1);

          mutations.single.complete();
          await secondMutationStarted.future;

          check(calls).deepEquals([false, true]);
          check(maximumActiveMutations).equals(1);

          mutations.last.complete();
          await request;

          check(cameraEnabled).isTrue();
        },
      );

      test(
        'drops stale camera requests when the latest state is disabled',
        () async {
          var cameraEnabled = true;
          final calls = <bool>[];
          final mutation = Completer<void>();

          when(
            () => mockLocalParticipant.isCameraEnabled(),
          ).thenAnswer((_) => cameraEnabled);
          when(() => mockLocalParticipant.setCameraEnabled(false)).thenAnswer((
            _,
          ) {
            calls.add(false);
            return mutation.future.then<LocalTrackPublication<LocalTrack>?>((
              _,
            ) {
              cameraEnabled = false;
              return null;
            });
          });

          final controller = container.read(
            sessionDeviceControllerProvider(mockSession).notifier,
          );
          final request = controller.disableCamera();
          unawaited(controller.enableCamera());
          unawaited(controller.disableCamera());

          check(calls).deepEquals([false]);
          mutation.complete();
          await request;

          check(calls).deepEquals([false]);
          check(cameraEnabled).isFalse();
        },
      );

      test('recovers after a camera mutation fails', () async {
        var cameraEnabled = true;
        var shouldFail = true;
        final calls = <bool>[];

        when(
          () => mockLocalParticipant.isCameraEnabled(),
        ).thenAnswer((_) => cameraEnabled);
        when(() => mockLocalParticipant.setCameraEnabled(false)).thenAnswer((
          _,
        ) {
          calls.add(false);
          if (shouldFail) {
            shouldFail = false;
            return Future<LocalTrackPublication<LocalTrack>?>.error(
              StateError('camera unavailable'),
            );
          }
          cameraEnabled = false;
          return Future<LocalTrackPublication<LocalTrack>?>.value();
        });

        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        );

        await controller.disableCamera();
        await controller.disableCamera();

        check(calls).deepEquals([false, false]);
        check(cameraEnabled).isFalse();
      });

      test('resetSpeakerRoutingDefaults resets preferences', () {
        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        )..resetSpeakerRoutingDefaults();
        check(controller.userSpeakerPreference).equals(true);
      });

      test('disposed controller rejects late device listener setup', () async {
        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        );

        await controller.dispose();
        await controller.setupDeviceChangeListener();
      });
    });
  });
}
