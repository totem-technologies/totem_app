// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';

import '../core/session_controller_mock.dart';
import 'session_device_controller_mock.dart';

void main() {
  group('SessionKeeperController', () {
    group('Keeper Disconnection Handling', () {
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

          check(mockSession.state.hasKeeper).equals(true);
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

          check(mockDevices.disableMicrophoneCalled).equals(true);
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

        check(controller.keeperDisconnectedTimer).isNotNull();

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

          check(firstTimer != secondTimer).equals(true);
          check(firstTimer!.isActive).equals(false);

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

        check(mockSession.state.hasKeeper).equals(true);
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
        check(controller.keeperDisconnectedTimer).isNotNull();

        controller.onKeeperConnected();
        check(controller.keeperDisconnectedTimer).isNull();
      });

      test('onKeeperConnected is idempotent', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        controller.onKeeperConnected();
        controller.onKeeperConnected();

        check(mockSession.state.hasKeeper).equals(true);
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

        check(controller.keeperDisconnectedTimer).isNull();
      });

      test('onKeeperDisconnectedTimeout disconnects from room', () async {
        final mockSession = FakeSessionController();

        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        await controller.onKeeperDisconnectedTimeout();

        check(mockSession.disconnectFromRoomCalled).equals(true);
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
        check(controller.keeperDisconnectedTimer).isNotNull();

        controller.disposePresenceTracking();
        check(controller.keeperDisconnectedTimer).isNull();
      });

      test('provider disposal cancels presence tracking', () async {
        final mockSession = FakeSessionController();
        mockSession.mockDevices = FakeSessionDeviceController();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final provider = sessionKeeperControllerProvider(mockSession);
        final subscription = container.listen(provider, (_, _) {});
        final controller = container.read(provider.notifier)
          ..onKeeperDisconnected(RoomStatus.active);
        check(controller.keeperDisconnectedTimer).isNotNull();

        subscription.close();
        await container.pump();

        check(controller.keeperDisconnectedTimer).isNull();
      });

      test('disposePresenceTracking is safe when no timer exists', () async {
        final mockSession = MockSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionKeeperControllerProvider(mockSession).notifier,
        );
        check(controller.keeperDisconnectedTimer).isNull();
        controller.disposePresenceTracking();
        check(controller.keeperDisconnectedTimer).isNull();
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

        check(controller.keeperDisconnectedTimer).isNull();
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
        check(mockSession.disconnectFromRoomCalled).equals(true);
        check(controller.keeperDisconnectedTimer).isNull();
      });
    });
  });
}
