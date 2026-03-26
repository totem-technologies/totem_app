// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/features/session_keeper_controller.dart';

import '../mocks.dart';

void main() {
  group('SessionKeeperController', () {
    group('Keeper Disconnection Handling', () {
      test('onKeeperDisconnected ignores non-active room status', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();

        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.onKeeperDisconnected(RoomStatus.waitingRoom);

        // When status is not active, keeper disconnected should not be marked
        expect(mockSession.lastKeeperDisconnectedValue, isNull);
      });

      test(
        'onKeeperDisconnected marks keeper as disconnected when room active',
        () async {
          final mockSession = FakeSessionController();
          final mockDevices = FakeSessionDeviceController();
          mockSession.mockDevices = mockDevices;

          final container = ProviderContainer();
          final controller = container.read(
            sessionKeeperControllerProvider(mockSession).notifier,
          );
          controller.onKeeperDisconnected(RoomStatus.active);

          expect(mockSession.lastKeeperDisconnectedValue, isTrue);
        },
      );

      test(
        'onKeeperDisconnected disables microphone when keeper disconnects',
        () async {
          final mockSession = FakeSessionController();
          final mockDevices = FakeSessionDeviceController();
          mockSession.mockDevices = mockDevices;

          final container = ProviderContainer();
          final controller = container.read(
            sessionKeeperControllerProvider(mockSession).notifier,
          );
          controller.onKeeperDisconnected(RoomStatus.active);

          expect(mockDevices.disableMicrophoneCalled, isTrue);
        },
      );

      test('onKeeperDisconnected starts timeout timer', () async {
        final mockSession = FakeSessionController();
        final mockDevices = FakeSessionDeviceController();
        mockSession.mockDevices = mockDevices;

        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.onKeeperDisconnected(RoomStatus.active);

        expect(controller.keeperDisconnectedTimer, isNotNull);

        controller.disposePresenceTracking();
      });

      test(
        'onKeeperDisconnected cancels previous timer before creating new one',
        () async {
          final mockSession = FakeSessionController();
          final mockDevices = FakeSessionDeviceController();
          mockSession.mockDevices = mockDevices;

          final container = ProviderContainer();
          final controller = container.read(
            sessionKeeperControllerProvider(mockSession).notifier,
          );
          controller.onKeeperDisconnected(RoomStatus.active);
          final firstTimer = controller.keeperDisconnectedTimer;

          controller.onKeeperDisconnected(RoomStatus.active);
          final secondTimer = controller.keeperDisconnectedTimer;

          expect(firstTimer != secondTimer, isTrue);
          expect(firstTimer!.isActive, isFalse);

          controller.disposePresenceTracking();
        },
      );
    });

    group('Keeper Reconnection Handling', () {
      test('onKeeperConnected marks keeper as connected', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.onKeeperConnected();

        expect(mockSession.lastKeeperDisconnectedValue, isFalse);
      });

      test('onKeeperConnected cancels disconnection timer', () async {
        final mockSession = FakeSessionController();
        final mockDevices = FakeSessionDeviceController();
        mockSession.mockDevices = mockDevices;

        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.onKeeperDisconnected(RoomStatus.active);
        expect(controller.keeperDisconnectedTimer, isNotNull);

        controller.onKeeperConnected();
        expect(controller.keeperDisconnectedTimer, isNull);
      });

      test('onKeeperConnected is idempotent', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.onKeeperConnected();
        controller.onKeeperConnected();

        expect(mockSession.lastKeeperDisconnectedValue, isFalse);
      });
    });

    group('Keeper Disconnection Timeout', () {
      test('onKeeperDisconnectedTimeout clears timer', () async {
        final mockSession = FakeSessionController();

        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.keeperDisconnectedTimer = Timer(
          const Duration(minutes: 3),
          () {},
        );

        await controller.onKeeperDisconnectedTimeout();

        expect(controller.keeperDisconnectedTimer, isNull);
      });

      test('onKeeperDisconnectedTimeout disconnects from room', () async {
        final mockSession = FakeSessionController();

        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        await controller.onKeeperDisconnectedTimeout();

        expect(mockSession.disconnectFromRoomCalled, isTrue);
      });
    });

    group('Presence Tracking Cleanup', () {
      test('disposePresenceTracking cancels timer', () async {
        final mockSession = FakeSessionController();
        final mockDevices = FakeSessionDeviceController();
        mockSession.mockDevices = mockDevices;

        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.onKeeperDisconnected(RoomStatus.active);
        expect(controller.keeperDisconnectedTimer, isNotNull);

        controller.disposePresenceTracking();
        expect(controller.keeperDisconnectedTimer, isNull);
      });

      test('disposePresenceTracking is safe when no timer exists', () async {
        final mockSession = MockSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        expect(controller.keeperDisconnectedTimer, isNull);
        controller.disposePresenceTracking();
        expect(controller.keeperDisconnectedTimer, isNull);
      });

      test('disposePresenceTracking is idempotent', () async {
        final mockSession = MockSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.disposePresenceTracking();
        controller.disposePresenceTracking();
        controller.disposePresenceTracking();

        expect(controller.keeperDisconnectedTimer, isNull);
      });
    });

    group('Error Handling', () {
      test('timeout method completes normally', () async {
        final mockSession = FakeSessionController();

        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );

        await controller.onKeeperDisconnectedTimeout();
        expect(mockSession.disconnectFromRoomCalled, isTrue);
        expect(controller.keeperDisconnectedTimer, isNull);
      });
    });
  });
}
