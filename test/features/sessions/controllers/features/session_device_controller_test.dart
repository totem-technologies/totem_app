import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';

import '../../livekit_mocks.dart';
import '../core/session_controller_mock.dart';

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
        mockRoom = FakeRoom(mockLocalParticipant)..setSpeakerOn(true);

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
  });
}
