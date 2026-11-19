import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';

class _Channel implements AdmissionChannel {
  _Channel(this.localIdentity);
  @override
  final String localIdentity;
  @override
  bool hasEnded = false;
  final present = <String>{};
  final sent = <AdmissionPacket>[];
  final controller = StreamController<AdmissionEvent>.broadcast(sync: true);
  Future<void> Function(AdmissionPacket)? onSend;
  @override
  Stream<AdmissionEvent> get events => controller.stream;
  @override
  Iterable<String> get remoteIdentities => present;
  @override
  bool isPresent(String identity) => present.contains(identity);
  @override
  Future<void> send(AdmissionPacket packet) {
    sent.add(packet);
    return onSend?.call(packet) ?? Future.value();
  }

  void receive(AdmissionPacket packet) =>
      controller.add(AdmissionPacketReceived(packet));
}

void main() {
  test(
    'keeper accepts only current committed member acknowledgements',
    () async {
      final now = DateTime.utc(2030);
      final channel = _Channel('keeper');
      final store = KeeperAdmissionRosterStore(keeperGeneration: 'generation')
        ..replace(['guest'], 4);
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
        now: () => now,
      );
      AdmissionRosterAck ack({
        String sender = 'guest',
        String recipient = 'keeper',
        String session = 'session',
        String generation = 'generation',
        int revision = 4,
        DateTime? expiry,
      }) => AdmissionRosterAck(
        id: 'ack',
        senderIdentity: sender,
        recipientIdentity: recipient,
        expiresAt: expiry ?? now.add(const Duration(minutes: 1)),
        sessionIdentity: session,
        keeperGeneration: generation,
        revision: revision,
      );
      [
        ack(sender: 'stranger'),
        ack(recipient: 'other'),
        ack(session: 'other'),
        ack(generation: 'other'),
        ack(revision: 5),
        ack(revision: -1),
        ack(expiry: now),
      ].forEach(channel.receive);
      check(keeper.acknowledgedRevisions.isEmpty).isTrue();
      channel
        ..receive(ack(revision: 3))
        ..receive(ack())
        ..receive(ack(revision: 2));
      check(keeper.acknowledgedRevisions['guest']).equals(4);
      await keeper.dispose();

      final restored = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
        now: () => now,
      );
      check(restored.keeperGeneration).equals('generation');
      check(restored.rosterRevision).equals(4);
      check(restored.roster).deepEquals(['guest']);
      check(restored.acknowledgedRevisions.isEmpty).isTrue();
      final inFlightAck = ack();
      channel
        ..receive(inFlightAck)
        ..receive(inFlightAck);
      check(restored.acknowledgedRevisions).deepEquals({'guest': 4});
      restored.revoke('guest');
      channel.receive(inFlightAck);
      check(restored.acknowledgedRevisions.isEmpty).isTrue();
      await restored.dispose();
      await channel.controller.close();
    },
  );

  test(
    'admitted client coalesces ACKs and periodically repairs missed updates',
    () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2030));
        final channel = _Channel('guest')..present.add('keeper');
        final firstAck = Completer<void>();
        channel.onSend = (packet) =>
            packet is AdmissionRosterAck && packet.revision == 1
            ? firstAck.future
            : Future.value();
        var nextId = 0;
        final client = ClientAdmissionRosterController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
          now: clock.now,
          newId: () => '${++nextId}',
          antiEntropyInterval: const Duration(seconds: 10),
        );
        void snapshot(int revision, List<String> members) {
          final request = channel.sent.whereType<AdmissionRosterRequest>().last;
          channel.receive(
            AdmissionRosterSnapshot(
              id: 'snapshot',
              requestId: request.id,
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: clock.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'generation',
              revision: revision,
              members: members,
            ),
          );
        }

        void update(int revision) => channel.receive(
          AdmissionRosterUpdated(
            id: 'update',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: clock.now().add(const Duration(minutes: 1)),
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: revision,
            members: const ['guest'],
          ),
        );
        snapshot(1, ['guest']);
        update(2);
        update(3);
        check(channel.sent.whereType<AdmissionRosterAck>().length).equals(1);
        firstAck.complete();
        async.flushMicrotasks();
        check(
          channel.sent
              .whereType<AdmissionRosterAck>()
              .map((ack) => ack.revision)
              .toList(),
        ).deepEquals([1, 3]);
        async.elapse(const Duration(seconds: 12));
        check(
          channel.sent.whereType<AdmissionRosterRequest>().length >= 2,
        ).isTrue();
        snapshot(4, ['guest', 'other']);
        check(client.contains('other')).isTrue();
        channel.controller.add(const AdmissionRoomDisconnected(null));
        final count = channel.sent.length;
        async.elapse(const Duration(minutes: 1));
        check(channel.sent.length).equals(count);
        client.dispose();
        channel.controller.close();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'pending request sends coalesce and stale completions cannot replace a new flight',
    () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2030));
        final channel = _Channel('guest')..present.add('keeper');
        final sends = <Completer<void>>[];
        channel.onSend = (packet) {
          if (packet is! AdmissionRosterRequest) return Future.value();
          final send = Completer<void>();
          sends.add(send);
          return send.future;
        };
        var id = 0;
        final client = ClientAdmissionRosterController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
          now: clock.now,
          newId: () => '${++id}',
        );
        async.elapse(const Duration(minutes: 2));
        check(sends.length > 1).isTrue();
        final retries = sends.length;
        sends.first.complete();
        async.flushMicrotasks();
        check(sends.length).equals(retries);
        channel.controller
          ..add(const AdmissionConnectionInterrupted())
          ..add(const AdmissionConnectionRestored());
        sends.last.completeError(StateError('stale'));
        async.flushMicrotasks();
        check(sends.length >= retries).isTrue();
        client.dispose();
        channel.controller.close();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'ACKs recover after interruption without stale completions clearing a new flight',
    () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2030));
        final channel = _Channel('guest')..present.add('keeper');
        final acks = <Completer<void>>[];
        channel.onSend = (packet) {
          if (packet is! AdmissionRosterAck) return Future.value();
          final send = Completer<void>();
          acks.add(send);
          return send.future;
        };
        var id = 0;
        final client = ClientAdmissionRosterController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
          now: clock.now,
          newId: () => '${++id}',
        );
        void snapshot(int revision) {
          final request = channel.sent.whereType<AdmissionRosterRequest>().last;
          channel.receive(
            AdmissionRosterSnapshot(
              id: 'snapshot',
              requestId: request.id,
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: clock.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'generation',
              revision: revision,
              members: const ['guest'],
            ),
          );
        }

        snapshot(1);
        async.flushMicrotasks();
        channel.controller.add(const AdmissionConnectionInterrupted());
        channel.controller.add(const AdmissionConnectionRestored());
        snapshot(1);
        check(acks.length).equals(2);
        acks.first.complete();
        async.flushMicrotasks();
        channel.receive(
          AdmissionRosterUpdated(
            id: 'update',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: clock.now().add(const Duration(minutes: 1)),
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 2,
            members: const ['guest'],
          ),
        );
        check(acks.length).equals(2);
        acks[1].complete();
        async.flushMicrotasks();
        check(acks.length).equals(3);
        client.dispose();
        channel.controller.close();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'lost ACK is resent on the next verified snapshot and missed updates repair independently',
    () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2030));
        final channels = [_Channel('alice'), _Channel('bob')];
        final clients = <ClientAdmissionRosterController>[];
        var id = 0;
        for (final channel in channels) {
          channel.present.add('keeper');
          clients.add(
            ClientAdmissionRosterController(
              channel: channel,
              keeperIdentity: () => 'keeper',
              sessionIdentity: 'session',
              now: clock.now,
              newId: () => '${++id}',
              antiEntropyInterval: const Duration(seconds: 10),
            ),
          );
        }
        void snapshot(_Channel channel, int revision, List<String> members) {
          final request = channel.sent.whereType<AdmissionRosterRequest>().last;
          channel.receive(
            AdmissionRosterSnapshot(
              id: 'snapshot',
              requestId: request.id,
              senderIdentity: 'keeper',
              recipientIdentity: channel.localIdentity,
              expiresAt: clock.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'generation',
              revision: revision,
              members: members,
            ),
          );
        }

        for (final channel in channels) {
          snapshot(channel, 1, ['alice', 'bob']);
        }
        async.flushMicrotasks();
        channels.first.receive(
          AdmissionRosterUpdated(
            id: 'update',
            senderIdentity: 'keeper',
            recipientIdentity: 'alice',
            expiresAt: clock.now().add(const Duration(minutes: 1)),
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 2,
            members: const ['alice', 'bob', 'charlie'],
          ),
        );
        check(clients[1].contains('charlie')).isFalse();
        async.elapse(const Duration(seconds: 12));
        final ackCount = channels.first.sent
            .whereType<AdmissionRosterAck>()
            .length;
        snapshot(channels.first, 1, ['alice', 'bob']);
        check(clients.first.contains('charlie')).isTrue();
        check(
          channels.first.sent.whereType<AdmissionRosterAck>().length,
        ).equals(ackCount);
        async.flushMicrotasks();
        for (final channel in channels) {
          snapshot(channel, 2, ['alice', 'bob', 'charlie']);
        }
        check(clients[1].contains('charlie')).isTrue();
        check(
          channels.first.sent
              .whereType<AdmissionRosterAck>()
              .where((ack) => ack.revision == 2)
              .length,
        ).equals(2);
        for (final client in clients) {
          client.dispose();
        }
        for (final channel in channels) {
          channel.controller.close();
        }
        async.flushMicrotasks();
      });
    },
  );

  test(
    'repeated interruptions cancel timers and restart only one recovery chain',
    () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2030));
        final channel = _Channel('guest')..present.add('keeper');
        var id = 0;
        final client = ClientAdmissionRosterController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
          now: clock.now,
          newId: () => '${++id}',
          antiEntropyInterval: const Duration(seconds: 10),
        );
        void snapshot() {
          final request = channel.sent.whereType<AdmissionRosterRequest>().last;
          channel.receive(
            AdmissionRosterSnapshot(
              id: 'snapshot',
              requestId: request.id,
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: clock.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'generation',
              revision: 1,
              members: const ['guest'],
            ),
          );
        }

        snapshot();
        async.flushMicrotasks();
        for (var i = 0; i < 3; i++) {
          channel.controller.add(const AdmissionConnectionInterrupted());
          final count = channel.sent.length;
          async.elapse(const Duration(minutes: 1));
          check(channel.sent.length).equals(count);
          channel.controller.add(const AdmissionConnectionRestored());
          snapshot();
          async.flushMicrotasks();
        }
        final count = channel.sent.whereType<AdmissionRosterRequest>().length;
        async.elapse(const Duration(seconds: 12));
        final requests =
            channel.sent.whereType<AdmissionRosterRequest>().length - count;
        check(requests >= 1 && requests <= 2).isTrue();
        client.dispose();
        channel.controller.close();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'presence event starts recovery before channel membership catches up',
    () {
      fakeAsync((async) {
        final channel = _Channel('guest');
        final client = ClientAdmissionRosterController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
        );
        check(channel.sent.isEmpty).isTrue();
        channel.controller.add(const AdmissionPresenceChanged('keeper', true));
        check(
          channel.sent.whereType<AdmissionRosterRequest>().length,
        ).equals(1);
        client.dispose();
        channel.controller.close();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'request retries proceed after a send timeout and ignore late settlement',
    () {
      fakeAsync((async) {
        final channel = _Channel('guest')..present.add('keeper');
        final sends = <Completer<void>>[];
        channel.onSend = (packet) {
          if (packet is! AdmissionRosterRequest) return Future.value();
          final send = Completer<void>();
          sends.add(send);
          return send.future;
        };
        final client = ClientAdmissionRosterController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
        );
        for (var i = 0; i < 10; i++) {
          channel.controller.add(const AdmissionConnectionInterrupted());
          channel.controller.add(const AdmissionConnectionRestored());
        }
        check(sends.length).equals(2);
        async.elapse(const Duration(seconds: 31));
        check(sends.length > 2).isTrue();
        final retries = sends.length;
        sends.first.completeError(StateError('abandoned'));
        async.flushMicrotasks();
        check(sends.length).equals(retries);
        client.dispose();
        channel.controller.close();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'interruption signals lost synchronization and ACK cap resumes after stale settlement',
    () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2030));
        final channel = _Channel('guest')..present.add('keeper');
        final acks = <Completer<void>>[];
        channel.onSend = (packet) {
          if (packet is! AdmissionRosterAck) return Future.value();
          final send = Completer<void>();
          acks.add(send);
          return send.future;
        };
        var id = 0;
        final client = ClientAdmissionRosterController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
          now: clock.now,
          newId: () => '${++id}',
        );
        final signals = <bool>[];
        final subscription = client.synchronizationChanges.listen(signals.add);
        void snapshot() {
          final request = channel.sent.whereType<AdmissionRosterRequest>().last;
          channel.receive(
            AdmissionRosterSnapshot(
              id: 'snapshot',
              requestId: request.id,
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: clock.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'generation',
              revision: 1,
              members: const ['guest'],
            ),
          );
          async.flushMicrotasks();
        }

        snapshot();
        check(client.isSynchronizing).isFalse();
        for (var i = 0; i < 10; i++) {
          channel.controller.add(const AdmissionConnectionInterrupted());
          check(client.isSynchronizing).isTrue();
          channel.controller.add(const AdmissionConnectionRestored());
          snapshot();
          check(client.isSynchronizing).isFalse();
        }
        check(signals.contains(true)).isTrue();
        check(acks.length).equals(2);
        acks.first.complete();
        async.flushMicrotasks();
        check(acks.length).equals(3);
        subscription.cancel();
        client.dispose();
        channel.controller.close();
        async.flushMicrotasks();
      });
    },
  );

  test('successful anti-entropy refresh does not enter recovery', () {
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2030));
      final channel = _Channel('guest')..present.add('keeper');
      final client = ClientAdmissionRosterController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        now: clock.now,
        antiEntropyInterval: const Duration(seconds: 1),
      );
      final signals = <bool>[];
      final subscription = client.synchronizationChanges.listen(signals.add);
      void respond() {
        final request = channel.sent.whereType<AdmissionRosterRequest>().last;
        channel.receive(
          AdmissionRosterSnapshot(
            id: 'snapshot-${request.id}',
            requestId: request.id,
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: clock.now().add(const Duration(minutes: 1)),
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 1,
            members: const ['guest'],
          ),
        );
      }

      respond();
      async.flushMicrotasks();
      signals.clear();
      async.elapse(const Duration(seconds: 2));
      check(channel.sent.whereType<AdmissionRosterRequest>().length).equals(2);
      respond();
      check(client.contains('guest')).isTrue();
      check(signals).isEmpty();
      client.dispose();
      channel.controller.close();
      subscription.cancel();
      async.flushMicrotasks();
    });
  });

  test('unadmitted snapshots do not produce ACKs or periodic requests', () {
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2030));
      final channel = _Channel('guest')..present.add('keeper');
      final client = ClientAdmissionRosterController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        now: clock.now,
        antiEntropyInterval: const Duration(seconds: 1),
      );
      final request = channel.sent.whereType<AdmissionRosterRequest>().single;
      channel.receive(
        AdmissionRosterSnapshot(
          id: 'snapshot',
          requestId: request.id,
          senderIdentity: 'keeper',
          recipientIdentity: 'guest',
          expiresAt: clock.now().add(const Duration(minutes: 1)),
          sessionIdentity: 'session',
          keeperGeneration: 'generation',
          revision: 1,
          members: const [],
        ),
      );
      async.elapse(const Duration(seconds: 10));
      check(channel.sent.whereType<AdmissionRosterAck>().isEmpty).isTrue();
      check(channel.sent.whereType<AdmissionRosterRequest>().length).equals(1);
      client.dispose();
      channel.controller.close();
      async.flushMicrotasks();
    });
  });
}
