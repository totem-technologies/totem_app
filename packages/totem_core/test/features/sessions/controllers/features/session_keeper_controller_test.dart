// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_runtime.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';

import '../../livekit_mocks.dart';
import '../../transport/fake_session_transport.dart';
import '../core/session_controller_mock.dart';
import 'session_device_controller_mock.dart';

class _PresenceDevices extends FakeSessionDeviceController {
  @override
  Future<void> disableMicrophone() async {
    await super.disableMicrophone();
    microphoneOn = false;
  }
}

/// Controllable connection/cleanup boundary for the real presence coordinator.
class _PresenceSession extends FakeSessionController {
  _PresenceSession() {
    mockDevices = _PresenceDevices();
  }
  bool connectionOpen = true;
  int cleanedConnections = 0;
  final leaveStarted = Completer<void>();
  Completer<void>? leaveGate;
  Error? leaveFailure;
  int leaveCalls = 0;

  @override
  Future<void> disconnectFromRoom() async {
    leaveCalls++;
    if (!leaveStarted.isCompleted) leaveStarted.complete();
    await leaveGate?.future;
    if (leaveFailure case final failure?) throw failure;
    connectionOpen = false;
    cleanedConnections++;
    disconnectFromRoomCalled = true;
  }
}

class _PresenceHarness {
  _PresenceHarness() {
    subscription = container.listen(
      sessionKeeperControllerProvider(session),
      (_, _) {},
    );
    controller = container.read(
      sessionKeeperControllerProvider(session).notifier,
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
  }
  final session = _PresenceSession();
  final container = ProviderContainer();
  late final ProviderSubscription<void> subscription;
  late final SessionKeeperController controller;
}

void main() {
  group('SessionKeeperController', () {
    group('Keeper presence lifecycle', () {
      test(
        'active loss mutes, repeated loss resets the deadline, and reconnect prevents exit',
        () {
          fakeAsync((clock) {
            final h = _PresenceHarness();
            h.controller.onKeeperDisconnected(RoomStatus.active);
            clock.flushMicrotasks();
            check(h.session.devices.isMicrophoneEnabled).isFalse();

            clock.elapse(const Duration(minutes: 2));
            h.controller.onKeeperDisconnected(RoomStatus.active);
            clock.elapse(const Duration(minutes: 1));
            clock.flushMicrotasks();
            // The first deadline has passed, but the replacement grace period has not.
            check(h.session.leaveCalls).equals(0);
            check(h.session.connectionOpen).isTrue();

            h.controller.onKeeperConnected();
            h.controller.onKeeperConnected();
            clock.elapse(const Duration(minutes: 4));
            clock.flushMicrotasks();
            check(h.session.leaveCalls).equals(0);
            check(h.session.cleanedConnections).equals(0);
          });
        },
      );

      test(
        'an expired active-room grace period disconnects and releases the connection once',
        () {
          fakeAsync((clock) {
            final h = _PresenceHarness();
            h.controller.onKeeperDisconnected(RoomStatus.active);
            clock.elapse(
              SessionKeeperController.keeperDisconnectionTimeout -
                  const Duration(microseconds: 1),
            );
            clock.flushMicrotasks();
            check(h.session.connectionOpen).isTrue();
            check(h.session.leaveCalls).equals(0);

            clock.elapse(const Duration(microseconds: 1));
            clock.flushMicrotasks();
            check(h.session.disconnectFromRoomCalled).isTrue();
            check(h.session.connectionOpen).isFalse();
            check(h.session.cleanedConnections).equals(1);
            clock.elapse(SessionKeeperController.keeperDisconnectionTimeout);
            clock.flushMicrotasks();
            check(h.session.leaveCalls).equals(1);
          });
        },
      );

      test(
        'waiting-room absence and repeated cancellation cannot end the session',
        () {
          fakeAsync((clock) {
            final h = _PresenceHarness();
            h.controller.onKeeperDisconnected(RoomStatus.waitingRoom);
            clock.elapse(SessionKeeperController.keeperDisconnectionTimeout);
            clock.flushMicrotasks();
            check(h.session.devices.isMicrophoneEnabled).isTrue();
            check(h.session.leaveCalls).equals(0);

            h.controller.onKeeperDisconnected(RoomStatus.active);
            h.controller.disposePresenceTracking();
            h.controller.disposePresenceTracking();
            clock.elapse(SessionKeeperController.keeperDisconnectionTimeout);
            clock.flushMicrotasks();
            check(h.session.leaveCalls).equals(0);
            check(h.session.connectionOpen).isTrue();
          });
        },
      );

      test(
        'timeout completion awaits connection cleanup rather than only starting leave',
        () async {
          final h = _PresenceHarness();
          final cleanup = h.session.leaveGate = Completer<void>();
          h.controller.onKeeperDisconnected(RoomStatus.active);
          var completed = false;
          final leaving = h.controller.onKeeperDisconnectedTimeout().then(
            (_) => completed = true,
          );
          await h.session.leaveStarted.future;
          check(completed).isFalse();
          check(h.session.connectionOpen).isTrue();
          check(h.session.cleanedConnections).equals(0);

          cleanup.complete();
          await leaving;
          check(completed).isTrue();
          check(h.session.disconnectFromRoomCalled).isTrue();
          check(h.session.cleanedConnections).equals(1);
        },
      );

      test(
        'lifecycle cleanup failure is not a successful timeout and can be retried explicitly',
        () async {
          final h = _PresenceHarness();
          final failure = StateError('connection cleanup failed');
          h.session.leaveFailure = failure;
          h.controller.onKeeperDisconnected(RoomStatus.active);
          await check(
            h.controller.onKeeperDisconnectedTimeout(),
          ).throws<StateError>();
          check(h.session.disconnectFromRoomCalled).isFalse();
          check(h.session.connectionOpen).isTrue();
          check(h.session.cleanedConnections).equals(0);

          h.session.leaveFailure = null;
          await h.controller.onKeeperDisconnectedTimeout();
          check(h.session.disconnectFromRoomCalled).isTrue();
          check(h.session.cleanedConnections).equals(1);
        },
      );

      test(
        'removing the final provider listener cancels its timeout without closing the session',
        () async {
          final h = _PresenceHarness();
          final clock = FakeAsync();
          clock.run(
            (_) => h.controller.onKeeperDisconnected(RoomStatus.active),
          );
          clock.flushMicrotasks();
          check(h.session.devices.isMicrophoneEnabled).isFalse();
          h.subscription.close();
          await h.container.pump();
          clock.elapse(SessionKeeperController.keeperDisconnectionTimeout);
          clock.flushMicrotasks();
          check(h.session.leaveCalls).equals(0);
          check(h.session.connectionOpen).isTrue();
          check(h.session.cleanedConnections).equals(0);
        },
      );
    });
    group('removeParticipant', () {
      test('does not remove while admission recovery is unavailable', () async {
        final session = FakeSessionController()
          ..isCurrentUserKeeperValue = true;
        var backendCalls = 0;
        final container = ProviderContainer(
          overrides: [
            removeParticipantProvider(
              session.options.sessionSlug,
              'user-2',
            ).overrideWith((_) async {
              backendCalls++;
            }),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          sessionKeeperControllerProvider(session).notifier,
        );
        await check(
          controller.removeParticipant('user-2'),
        ).throws<StateError>();
        check(backendCalls).equals(0);
      });

      test('notifies once after backend removal succeeds', () async {
        final session = FakeSessionController()
          ..isCurrentUserKeeperValue = true;
        final started = Completer<void>();
        final backend = Completer<void>();
        final removed = <String>[];
        final container = ProviderContainer(
          overrides: [
            removeParticipantProvider(
              session.options.sessionSlug,
              'user-2',
            ).overrideWith((_) async {
              started.complete();
              await backend.future;
            }),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          sessionKeeperControllerProvider(session).notifier,
        );
        (session.admission as FakeAdmissionService).onRevoke = (slug) async =>
            removed.add(slug);

        final removal = controller.removeParticipant('user-2');
        await started.future;
        check(removed).isEmpty();
        backend.complete();
        await removal;

        check(removed).deepEquals(['user-2']);
      });

      test('does not notify when backend removal fails', () async {
        final session = FakeSessionController()
          ..isCurrentUserKeeperValue = true;
        final removed = <String>[];
        final container = ProviderContainer(
          overrides: [
            removeParticipantProvider(
              session.options.sessionSlug,
              'user-2',
            ).overrideWith((_) async => throw StateError('removal failed')),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          sessionKeeperControllerProvider(session).notifier,
        );
        (session.admission as FakeAdmissionService).onRevoke = (slug) async =>
            removed.add(slug);

        await check(
          controller.removeParticipant('user-2'),
        ).throws<StateError>();
        check(removed).isEmpty();
      });

      test('non-keeper neither removes nor notifies', () async {
        final session = FakeSessionController();
        var backendCalls = 0;
        final removed = <String>[];
        final container = ProviderContainer(
          overrides: [
            removeParticipantProvider(
              session.options.sessionSlug,
              'user-2',
            ).overrideWith((_) async {
              backendCalls++;
            }),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          sessionKeeperControllerProvider(session).notifier,
        );
        (session.admission as FakeAdmissionService).onRevoke = (slug) async =>
            removed.add(slug);

        await check(
          controller.removeParticipant('user-2'),
        ).throws<SessionCommandException>();

        check(backendCalls).equals(0);
        check(removed).isEmpty();
      });
    });

    test(
      'a late Keeper room-state response cannot update a replacement attempt',
      () async {
        final runtime = SessionRuntime(
          factory: FakeSessionTransportFactory(),
          onEvent: (_) {},
          onCancel: () {},
          onCleanup: () async {},
          onJoined: () {},
          onError: (_, _) {},
          activateInfrastructure: (_) async {},
          deactivateInfrastructure: (_) async {},
          retainEntry: () => () {},
        );
        await runtime.join(operation: (_) async => SessionJoinResult.success);
        final session = FakeSessionController()
          ..isCurrentUserKeeperValue = true
          ..activeAttempt = runtime.activeAttempt;
        final previous = session.state.roomState;
        final started = Completer<void>();
        final response = Completer<RoomState>();
        final container = ProviderContainer(
          overrides: [
            forcePassTotemProvider(
              session.options.sessionSlug,
              previous.version,
            ).overrideWith((_) {
              started.complete();
              return response.future;
            }),
          ],
        );
        final subscription = container.listen(
          sessionKeeperControllerProvider(session),
          (_, _) {},
        );
        final command = container
            .read(sessionKeeperControllerProvider(session).notifier)
            .forcePassTotem();
        final failed = check(command).throws<SessionCommandException>();
        await started.future;
        await runtime.cleanup();
        await runtime.join(operation: (_) async => SessionJoinResult.success);
        response.complete(previous.copyWith(version: previous.version + 10));
        await failed;
        check(session.state.roomState).identicalTo(previous);
        await runtime.dispose();
        subscription.close();
        container.dispose();
      },
    );

    group('acceptTotem', () {
      Future<FakeSessionDeviceController> accept({
        required bool microphoneStarts,
      }) async {
        final session = FakeSessionController()
          ..mockRoom = FakeRoom(MockLocalParticipant('user-2'));
        final devices = FakeSessionDeviceController()
          ..microphoneOn = false
          ..microphoneStarts = microphoneStarts;
        session.mockDevices = devices;
        final container = ProviderContainer(
          overrides: [
            acceptTotemProvider(
              session.options.sessionSlug,
              session.state.roomState.version,
            ).overrideWith(
              (_) async => session.state.roomState.copyWith(
                version: session.state.roomState.version + 1,
                status: RoomStatus.active,
                currentSpeaker: const Omittable('user-2'),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionKeeperControllerProvider(session).notifier)
            .acceptTotem();
        return devices;
      }

      test(
        'X13: a mic that does not come on is flagged, not a failure',
        () async {
          final devices = await accept(microphoneStarts: false);

          check(devices.turnedOn).deepEquals([MediaKind.microphone]);
          check(devices.flagged).deepEquals([MediaKind.microphone]);
        },
      );

      test('a mic that comes on is not flagged', () async {
        final devices = await accept(microphoneStarts: true);

        check(devices.flagged).isEmpty();
      });
    });
  });
}
