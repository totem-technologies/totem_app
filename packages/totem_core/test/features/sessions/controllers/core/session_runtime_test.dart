import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/controllers/core/session_poll_scheduler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_runtime.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../../transport/fake_session_transport.dart';

class _Harness {
  _Harness({this.previousEntryCleanup});
  final Future<void>? previousEntryCleanup;
  final factory = FakeSessionTransportFactory();
  final events = <SessionTransportEvent>[];
  final errors = <Object>[];
  final activeInfrastructure = <Object>{};
  int joined = 0;
  int retained = 0;
  Future<void> Function()? cleaning;
  late final runtime = SessionRuntime(
    factory: factory,
    previousEntryCleanup: previousEntryCleanup,
    onEvent: events.add,
    onCancel: () {},
    onCleanup: () async {
      await cleaning?.call();
    },
    onJoined: () => joined++,
    onError: (error, _) => errors.add(error),
    activateInfrastructure: (owner) async {
      activeInfrastructure.add(owner);
    },
    deactivateInfrastructure: (owner) async {
      activeInfrastructure.remove(owner);
    },
    retainEntry: () {
      retained++;
      return () {
        retained--;
      };
    },
  );

  Future<SessionJoinResult> connect(SessionAttempt attempt) async {
    final transport = await runtime.prepare(attempt, 'url', 'token');
    await runtime.activate();
    attempt.requireCurrent();
    await transport.connect('url', 'token');
    attempt.requireCurrent();
    return SessionJoinResult.success;
  }

  Future<void> leave() => runtime.leave(
    disconnect: () async {
      await runtime.transport?.disconnect();
    },
  );
}

void main() {
  for (final result in SessionJoinResult.values) {
    test('concurrent joins wait for the same $result', () async {
      final h = _Harness();
      final gate = Completer<SessionJoinResult>();
      var calls = 0;
      Future<SessionJoinResult> operation(SessionAttempt _) {
        calls++;
        return gate.future;
      }

      final first = h.runtime.join(operation: operation);
      var completed = false;
      final second = h.runtime.join(operation: operation).then((value) {
        completed = true;
        return value;
      });
      await Future<void>.value();
      check(completed).isFalse();
      check(calls).equals(1);
      gate.complete(result);
      check(await first).equals(result);
      check(await second).equals(result);
      check(h.joined).equals(result == SessionJoinResult.success ? 1 : 0);
      check(h.retained).equals(0);
      await h.runtime.dispose();
    });
  }

  test(
    'leave cancels pending connect; its late completion cannot affect a new entry',
    () async {
      final h = _Harness();
      final gate = Completer<void>();
      final started = Completer<void>();
      final oldEntry = h.runtime.entryIdentity;
      final first = h.runtime.join(
        operation: (attempt) async {
          final transport =
              (await h.runtime.prepare(attempt, 'url', 'token')
                    as FakeSessionTransport)
                ..connectCompletion = gate;
          final connecting = transport.connect('url', 'token');
          started.complete();
          await connecting;
          return SessionJoinResult.success;
        },
      );
      await started.future;
      await Future.wait([h.leave(), h.leave()]);
      final old = h.factory.created.single;
      check(old.underlyingDisposals).equals(1);
      check(
        await h.runtime.join(operation: h.connect),
      ).equals(SessionJoinResult.success);
      check(identical(h.runtime.entryIdentity, oldEntry)).isFalse();
      final current = h.runtime.transport;
      gate.complete();
      check(await first).equals(SessionJoinResult.retryableFailure);
      check(h.runtime.transport).identicalTo(current);
      check(h.runtime.phase).equals(SessionRuntimePhase.connected);
      check(h.joined).equals(1);
      await h.runtime.dispose();
      await h.runtime.dispose();
      check(h.factory.created.last.underlyingDisposals).equals(1);
      check(h.activeInfrastructure).isEmpty();
    },
  );

  test(
    'a new join waits for cleanup without sharing the cancelled attempt',
    () async {
      final h = _Harness();
      final pending = Completer<SessionJoinResult>();
      final oldJoin = h.runtime.join(operation: (_) => pending.future);
      final cleanupStarted = Completer<void>();
      final cleanupGate = Completer<void>();
      h.cleaning = () {
        cleanupStarted.complete();
        return cleanupGate.future;
      };
      final cleanup = h.runtime.cleanup();
      await cleanupStarted.future;
      final nextJoin = h.runtime.join(operation: h.connect);
      check(h.factory.created).isEmpty();
      h.cleaning = null;
      cleanupGate.complete();
      await cleanup;
      check(await nextJoin).equals(SessionJoinResult.success);
      pending.complete(SessionJoinResult.success);
      check(await oldJoin).equals(SessionJoinResult.retryableFailure);
      check(h.joined).equals(1);
      check(h.retained).equals(0);
      await h.runtime.dispose();
    },
  );

  test(
    'retry waits for old cleanup, and old events cannot reach the new attempt',
    () async {
      final h = _Harness();
      check(
        await h.runtime.join(operation: h.connect),
      ).equals(SessionJoinResult.success);
      final old = h.factory.created.single;
      final cleanupStarted = Completer<void>();
      final cleanupGate = Completer<void>();
      h.cleaning = () {
        cleanupStarted.complete();
        return cleanupGate.future;
      };
      final cleanup = h.runtime.cleanup();
      await cleanupStarted.future;
      final joining = h.runtime.join(operation: h.connect);
      old.emit(const TransportMetadataChanged('stale'));
      check(h.events.whereType<TransportMetadataChanged>()).isEmpty();
      check(h.factory.created).length.equals(1);
      h.cleaning = null;
      cleanupGate.complete();
      await cleanup;
      check(await joining).equals(SessionJoinResult.success);
      check(h.factory.created).length.equals(2);
      check(old.underlyingDisposals).equals(1);
      await h.runtime.dispose();
    },
  );

  test(
    'adoption consumes the connected lease once, without connecting again',
    () async {
      final h = _Harness();
      final connection = FakeSessionTransport();
      await connection.connect('url', 'token');
      final lease = ConnectedSessionLease(connection);
      check(
        await h.runtime.join(
          offer: lease,
          operation: (_) async => SessionJoinResult.success,
        ),
      ).equals(SessionJoinResult.success);
      await lease.dispose();
      check(lease.claim).throws<StateError>();
      check(connection.connectCalls).equals(1);
      check(connection.underlyingDisposals).equals(0);
      check(h.factory.created).isEmpty();
      await h.runtime.dispose();
      check(connection.underlyingDisposals).equals(1);
    },
  );

  test(
    'a disconnected offer is released once and leaves no active owner',
    () async {
      final h = _Harness();
      final connection = FakeSessionTransport();
      await connection.connect('url', 'token');
      final lease = ConnectedSessionLease(connection);
      await connection.disconnect();
      check(
        await h.runtime.join(offer: lease, operation: h.connect),
      ).equals(SessionJoinResult.retryableFailure);
      check(connection.underlyingDisposals).equals(1);
      check(h.runtime.transport).isNull();
      check(h.runtime.phase).equals(SessionRuntimePhase.recoverableFailure);
      check(h.retained).equals(0);
      await lease.dispose();
      await h.runtime.dispose();
      check(connection.underlyingDisposals).equals(1);
    },
  );

  test(
    'reconnect keeps the connection and page exit initiates disconnect immediately',
    () async {
      final h = _Harness();
      check(
        await h.runtime.join(operation: h.connect),
      ).equals(SessionJoinResult.success);
      final connection = h.factory.created.single
        ..emit(
          const TransportConnectionChanged(
            SessionTransportConnectionState.reconnecting,
          ),
        );
      check(h.runtime.phase).equals(SessionRuntimePhase.reconnecting);
      connection.emit(
        const TransportConnectionChanged(
          SessionTransportConnectionState.connected,
          reconnected: true,
        ),
      );
      check(h.runtime.phase).equals(SessionRuntimePhase.connected);
      check(connection.connectCalls).equals(1);
      h.runtime.leaveOnPageExit();
      check(connection.disconnectCalls).equals(1);
      await h.runtime.dispose();
      check(connection.underlyingDisposals).equals(1);
    },
  );

  test(
    'cleanup failures still release connection and infrastructure',
    () async {
      final h = _Harness();
      check(
        await h.runtime.join(operation: h.connect),
      ).equals(SessionJoinResult.success);
      h.cleaning = () async {
        throw StateError('feature cleanup failed');
      };
      await check(h.runtime.dispose()).throws<StateError>();
      check(h.runtime.phase).equals(SessionRuntimePhase.disposed);
      check(h.factory.created.single.underlyingDisposals).equals(1);
      check(h.activeInfrastructure).isEmpty();
      check(h.runtime.transport).isNull();
    },
  );

  test(
    'a replacement runtime waits for the previous entry to release its connection',
    () async {
      final old = _Harness();
      await old.runtime.join(operation: old.connect);
      final cleanupStarted = Completer<void>();
      final gate = Completer<void>();
      old.cleaning = () {
        cleanupStarted.complete();
        return gate.future;
      };
      final next = _Harness(previousEntryCleanup: old.runtime.dispose());
      await cleanupStarted.future;
      final joining = next.runtime.join(operation: next.connect);
      await Future<void>.value();
      check(next.factory.created).isEmpty();
      gate.complete();
      check(await joining).equals(SessionJoinResult.success);
      check(old.runtime.phase).equals(SessionRuntimePhase.disposed);
      check(old.factory.created.single.underlyingDisposals).equals(1);
      check(next.factory.created.single.underlyingDisposals).equals(0);
      await next.runtime.dispose();
    },
  );

  test(
    'a failed previous runtime cleanup does not block a later join',
    () async {
      final previousCleanup = Future<void>.error(
        StateError('disconnect failed'),
      );
      final next = _Harness(previousEntryCleanup: previousCleanup);
      check(
        await next.runtime.join(operation: next.connect),
      ).equals(SessionJoinResult.success);
      check(next.factory.created).length.equals(1);
      await next.runtime.dispose();
    },
  );

  test('terminal failure requires an explicit reset before retry', () async {
    final h = _Harness();
    check(
      await h.runtime.join(
        operation: (_) async => SessionJoinResult.fatalFailure,
      ),
    ).equals(SessionJoinResult.fatalFailure);
    check(
      await h.runtime.join(operation: h.connect),
    ).equals(SessionJoinResult.fatalFailure);
    check(h.factory.created).isEmpty();
    await h.runtime.reset();
    check(
      await h.runtime.join(operation: h.connect),
    ).equals(SessionJoinResult.success);
    await h.runtime.dispose();
  });

  test(
    'polling coalesces requests and replaces schedules without overlapping fetches',
    () {
      fakeAsync((clock) {
        final scheduler = SessionPollScheduler();
        final gate = Completer<void>();
        final fetches = <bool>[];
        var synchronizations = 0;
        void start() => scheduler.start(
          syncInterval: const Duration(seconds: 20),
          pollInterval: const Duration(seconds: 15),
          synchronize: () => synchronizations++,
          fetch: (reconcile) {
            fetches.add(reconcile);
            return fetches.length == 1 ? gate.future : Future.value();
          },
        );
        start();
        clock.elapse(const Duration(seconds: 15));
        unawaited(scheduler.request(reconcile: true));
        clock.elapse(const Duration(seconds: 15));
        check(fetches).deepEquals([false]);
        start();
        unawaited(scheduler.request(reconcile: true));
        clock.flushMicrotasks();
        check(fetches).length.equals(1);
        gate.complete();
        clock.flushMicrotasks();
        check(fetches).deepEquals([false, true]);
        clock
          ..elapse(const Duration(seconds: 20))
          ..flushMicrotasks();
        check(synchronizations).equals(2);
        scheduler.stop();
        final count = fetches.length;
        clock
          ..elapse(const Duration(minutes: 2))
          ..flushMicrotasks();
        check(fetches).length.equals(count);
        check(clock.periodicTimerCount).equals(0);
      });
    },
  );
}
