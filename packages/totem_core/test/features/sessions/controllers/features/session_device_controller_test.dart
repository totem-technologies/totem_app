import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';

import '../../livekit_mocks.dart';
import '../core/session_controller_mock.dart';

MediaDevice _device({
  String deviceId = 'default',
  String label = 'Default',
  String kind = 'audiooutput',
}) {
  return MediaDevice(deviceId, label, kind, null);
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCameraCaptureOptions());
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

      test('resetSpeakerRoutingDefaults resets preferences', () {
        final controller = container.read(
          sessionDeviceControllerProvider(mockSession).notifier,
        )..resetSpeakerRoutingDefaults();
        expect(controller.userSpeakerPreference, isTrue);
      });
    });

    group('Web audio routing helpers', () {
      group('hasExternalAudioOutput', () {
        test('returns false for empty list', () {
          expect(
            SessionDeviceController.hasExternalAudioOutput([]),
            isFalse,
          );
        });

        test('returns false when only default device present', () {
          final devices = [_device(label: 'Default')];
          expect(
            SessionDeviceController.hasExternalAudioOutput(devices),
            isFalse,
          );
        });

        test('returns false for empty-label device', () {
          final devices = [_device(label: '')];
          expect(
            SessionDeviceController.hasExternalAudioOutput(devices),
            isFalse,
          );
        });

        test('returns true when a labeled non-default device is present', () {
          final devices = [
            _device(label: 'Default'),
            _device(label: 'External Headphones'),
          ];
          expect(
            SessionDeviceController.hasExternalAudioOutput(devices),
            isTrue,
          );
        });

        test('returns true for bluetooth device with label', () {
          final devices = [
            _device(label: 'Default'),
            _device(label: 'AirPods Pro'),
          ];
          expect(
            SessionDeviceController.hasExternalAudioOutput(devices),
            isTrue,
          );
        });

        test('returns true when multiple external devices present', () {
          final devices = [
            _device(label: 'Default'),
            _device(label: 'Communications - Headset'),
            _device(label: 'Speaker (Built-in)'),
          ];
          expect(
            SessionDeviceController.hasExternalAudioOutput(devices),
            isTrue,
          );
        });
      });

      group('findSpeakerTarget', () {
        test('returns null for empty list', () {
          expect(
            SessionDeviceController.findSpeakerTarget([], true),
            isNull,
          );
          expect(
            SessionDeviceController.findSpeakerTarget([], false),
            isNull,
          );
        });

        test('returns default device when speaker preferred', () {
          final devices = [
            _device(deviceId: 'default', label: 'Default'),
            _device(label: 'Communications - Headset'),
          ];
          final target = SessionDeviceController.findSpeakerTarget(
            devices,
            true,
          );
          expect(target?.deviceId, 'default');
        });

        test(
          'returns communications device when external output preferred',
          () {
            final devices = [
              _device(deviceId: 'default', label: 'Default'),
              _device(
                deviceId: 'comms',
                label: 'Communications - Headset',
              ),
            ];
            final target = SessionDeviceController.findSpeakerTarget(
              devices,
              false,
            );
            expect(target?.deviceId, 'comms');
          },
        );

        test('falls back to default when no comms device and speaker off', () {
          final devices = [
            _device(deviceId: 'default', label: 'Default'),
            _device(label: 'External Speakers'),
          ];
          final target = SessionDeviceController.findSpeakerTarget(
            devices,
            false,
          );
          expect(target?.deviceId, 'default');
        });

        test('matches deviceId "default" even without label', () {
          final devices = [
            _device(deviceId: 'default', label: ''),
          ];
          final target = SessionDeviceController.findSpeakerTarget(
            devices,
            true,
          );
          expect(target?.deviceId, 'default');
        });

        test('matches label containing "Default"', () {
          final devices = [
            _device(
              deviceId: 'speaker1',
              label: 'Default - Speakers (Built-in)',
            ),
          ];
          final target = SessionDeviceController.findSpeakerTarget(
            devices,
            true,
          );
          expect(target?.deviceId, 'speaker1');
        });

        test('case-insensitive communications match', () {
          final devices = [
            _device(
              deviceId: 'headset',
              label: 'COMMUNICATIONS - Headset',
            ),
          ];
          final target = SessionDeviceController.findSpeakerTarget(
            devices,
            false,
          );
          expect(target?.deviceId, 'headset');
        });
      });
    });
  });
}
