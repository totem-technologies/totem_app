import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';

class _Channel implements AdmissionChannel {
  final controller = StreamController<AdmissionEvent>.broadcast(sync: true);
  final sent = <AdmissionPacket>[];
  @override
  String get localIdentity => 'keeper';
  @override
  bool get hasEnded => false;
  @override
  Iterable<String> get remoteIdentities => ['alice', 'bob'];
  @override
  bool isPresent(String identity) => remoteIdentities.contains(identity);
  @override
  Stream<AdmissionEvent> get events => controller.stream;
  @override
  Future<void> send(AdmissionPacket packet) async {
    sent.add(packet);
  }
}

void main() {
  test(
    'an earlier persisted receipt cannot mark a superseding request joined',
    () async {
      final now = DateTime.utc(2030);
      final channel = _Channel();
      final writes = <Completer<void>>[];
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        now: () => now,
        persistRoster: () {
          final gate = Completer<void>();
          writes.add(gate);
          return gate.future;
        },
      );
      final expiry = now.add(const Duration(minutes: 1));
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'old',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
            displayName: 'Alice',
          ),
        ),
      );
      await keeper.approve('old', 'alice');
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionJoined(
            id: 'old',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
          ),
        ),
      );
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'new',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry.add(const Duration(seconds: 1)),
            displayName: 'Alice',
          ),
        ),
      );
      await Future<void>.value();
      check(keeper.attempts.single.request.id).equals('new');
      writes.first.complete();
      writes.last.complete();
      await keeper.pendingRosterWrites;
      check(keeper.attempts.single.request.id).equals('new');
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      await keeper.dispose();
      await channel.controller.close();
    },
  );

  test(
    'quarantine suppresses roster announcements and clearing restores committed membership',
    () async {
      final now = DateTime.utc(2030);
      final channel = _Channel();
      final store = KeeperAdmissionRosterStore()..replace(['alice', 'bob'], 7);
      var saves = 0;
      final quarantined = {'alice'};
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
        quarantinedIdentities: quarantined,
        now: () => now,
        persistRoster: () async {
          saves++;
        },
      );
      quarantined.clear();
      check(keeper.roster).deepEquals(['bob']);
      check(channel.sent.whereType<AdmissionRosterSnapshot>()).isEmpty();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterRequest(
            id: 'snapshot',
            senderIdentity: 'bob',
            recipientIdentity: 'keeper',
            sessionIdentity: 'session',
            expiresAt: now.add(const Duration(minutes: 1)),
          ),
        ),
      );
      check(channel.sent.whereType<AdmissionRosterSnapshot>()).isEmpty();
      check(store.members).deepEquals(['alice', 'bob']);
      check(store.revision).equals(7);
      check(saves).equals(0);
      keeper.setQuarantinedIdentities({});
      check(keeper.roster).deepEquals(['alice', 'bob']);
      final update = channel.sent.whereType<AdmissionRosterUpdated>().last;
      check(update.revision).equals(7);
      check(update.members).deepEquals(['alice', 'bob']);
      keeper.setQuarantinedIdentities({'alice'});
      check(keeper.roster).deepEquals(['bob']);
      check(saves).equals(0);
      await keeper.dispose();
      await channel.controller.close();
    },
  );

  test(
    'quarantined requests are not approved automatically or explicitly',
    () async {
      final now = DateTime.utc(2030);
      final channel = _Channel();
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        approvalRequired: false,
        quarantinedIdentities: {'alice'},
        now: () => now,
      );
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'request',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: now.add(const Duration(minutes: 1)),
            displayName: 'Alice',
          ),
        ),
      );
      await Future<void>.value();
      check(channel.sent.whereType<AdmissionDecision>()).isEmpty();
      await check(keeper.approve('request', 'alice')).throws<StateError>();
      check(channel.sent.whereType<AdmissionDecision>()).isEmpty();
      keeper.setQuarantinedIdentities({});
      await Future<void>.value();
      check(
        channel.sent.whereType<AdmissionDecision>().single.approved,
      ).isTrue();
      await keeper.dispose();
      await channel.controller.close();
    },
  );

  test(
    'restriction failure preserves the committed revision and retry announces the exact saved snapshot',
    () async {
      final now = DateTime.utc(2030);
      final expiry = now.add(const Duration(minutes: 1));
      final channel = _Channel();
      final store = KeeperAdmissionRosterStore(keeperGeneration: 'generation')
        ..replace(['alice', 'bob'], 4);
      final writes = <Completer<void>>[];
      final snapshots = <(int, List<String>, List<String>)>[];
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
        now: () => now,
        persistRoster: () {
          snapshots.add((
            store.revision,
            store.members.toList(),
            store.awaitingReadiness.toList(),
          ));
          final write = Completer<void>();
          writes.add(write);
          return write.future;
        },
      );
      channel.sent.clear();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'return',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
            displayName: 'Alice',
          ),
        ),
      );
      check(keeper.roster).deepEquals(['bob']);
      check(keeper.rosterRevision).equals(4);
      check(snapshots).length.equals(1);
      check(snapshots.single.$1).equals(5);
      check(snapshots.single.$2).deepEquals(['alice', 'bob']);
      check(snapshots.single.$3).deepEquals(['alice']);
      check(channel.sent.whereType<AdmissionRosterUpdated>()).isEmpty();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterRequest(
            id: 'before',
            senderIdentity: 'bob',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
            sessionIdentity: 'session',
          ),
        ),
      );
      check(channel.sent.whereType<AdmissionRosterSnapshot>()).isEmpty();
      writes.single.completeError(StateError('disk'));
      await keeper.pendingRosterWrites;
      check(keeper.rosterRevision).equals(4);
      check(keeper.persistenceError).isA<StateError>();
      final retry = keeper.retryRosterPersistence();
      writes.last.complete();
      await retry;
      final update = channel.sent.whereType<AdmissionRosterUpdated>().last;
      check(update.revision).equals(5);
      check(update.members).deepEquals(['bob']);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterRequest(
            id: 'after',
            senderIdentity: 'bob',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
            sessionIdentity: 'session',
          ),
        ),
      );
      final reply = channel.sent.whereType<AdmissionRosterSnapshot>().last;
      check(reply.revision).equals(update.revision);
      check(reply.members).deepEquals(update.members);
      await keeper.dispose();
      await channel.controller.close();
    },
  );

  test(
    'a pending grant and revocation announce only their exact persisted snapshot',
    () async {
      final now = DateTime.utc(2030);
      final expiry = now.add(const Duration(minutes: 1));
      final channel = _Channel();
      final store = KeeperAdmissionRosterStore()..replace(['bob'], 1);
      final writes = <Completer<void>>[];
      final snapshots = <(int, List<String>)>[];
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
        now: () => now,
        persistRoster: () {
          snapshots.add((store.revision, store.members.toList()..sort()));
          final write = Completer<void>();
          writes.add(write);
          return write.future;
        },
      );
      channel.sent.clear();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'new',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
            displayName: 'Alice',
          ),
        ),
      );
      await keeper.approve('new', 'alice');
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionJoined(
            id: 'new',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
          ),
        ),
      );
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      keeper.revoke('bob', persist: false);
      check(snapshots).length.equals(1);
      check(snapshots[0].$1).equals(2);
      check(snapshots[0].$2).deepEquals(['alice', 'bob']);
      check(store.revision).equals(3);
      check(store.members).deepEquals(['alice']);
      check(store.revoked).deepEquals({'bob'});
      check(keeper.roster).isEmpty();
      check(keeper.rosterRevision).equals(1);
      check(channel.sent.whereType<AdmissionRosterUpdated>()).isEmpty();
      final journalMembers = store.members.toList();
      final journalAwaiting = store.awaitingReadiness.toList();
      final journalRevoked = store.revoked.toList();
      keeper
        ..acknowledgeJournaledRoster(
          keeperGeneration: 'wrong',
          revision: 3,
          members: journalMembers,
          awaitingReadiness: journalAwaiting,
          revoked: journalRevoked,
        )
        ..acknowledgeJournaledRoster(
          keeperGeneration: store.keeperGeneration,
          revision: 4,
          members: journalMembers,
          awaitingReadiness: journalAwaiting,
          revoked: journalRevoked,
        );
      check(keeper.rosterRevision).equals(1);
      keeper.acknowledgeJournaledRoster(
        keeperGeneration: store.keeperGeneration,
        revision: 3,
        members: journalMembers,
        awaitingReadiness: journalAwaiting,
        revoked: journalRevoked,
      );
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
      final update = channel.sent.whereType<AdmissionRosterUpdated>().last;
      check(update.revision).equals(3);
      check(update.members).deepEquals(['alice']);
      writes.single.complete();
      await keeper.pendingRosterWrites;
      check(keeper.rosterRevision).equals(3);
      check(keeper.roster).deepEquals(['alice']);
      check(channel.sent.whereType<AdmissionRosterUpdated>()).length.equals(1);
      keeper
        ..revoke('alice', persist: false)
        ..acknowledgeJournaledRoster(
          keeperGeneration: store.keeperGeneration,
          revision: 3,
          members: journalMembers,
          awaitingReadiness: journalAwaiting,
          revoked: journalRevoked,
        );
      check(keeper.roster).isEmpty();
      check(channel.sent.whereType<AdmissionRosterUpdated>()).length.equals(1);
      await keeper.dispose();
      await channel.controller.close();
    },
  );

  test('failed journal leaves revocation local and unannounced', () async {
    final channel = _Channel();
    final store = KeeperAdmissionRosterStore()..replace(['alice', 'bob'], 1);
    var saves = 0;
    final journal = Completer<void>();
    final keeper = KeeperAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      sessionIdentity: 'session',
      rosterStore: store,
      persistRoster: () async {
        saves++;
      },
    );
    channel.sent.clear();
    keeper.revoke('alice', persist: false);
    final generation = store.keeperGeneration;
    final revision = store.revision;
    final members = store.members.toList();
    final awaiting = store.awaitingReadiness.toList();
    final revoked = store.revoked.toList();
    final operation = journal.future
        .then((_) {
          keeper.acknowledgeJournaledRoster(
            keeperGeneration: generation,
            revision: revision,
            members: members,
            awaitingReadiness: awaiting,
            revoked: revoked,
          );
        })
        .catchError((Object _) {});
    journal.completeError(StateError('journal failed'));
    await operation;
    check(saves).equals(0);
    check(keeper.roster).deepEquals(['bob']);
    check(keeper.rosterRevision).equals(1);
    check(channel.sent.whereType<AdmissionRosterUpdated>()).isEmpty();
    await keeper.dispose();
    await channel.controller.close();
  });

  test('a superseded keeper never announces a completed write', () async {
    final channel = _Channel();
    final store = KeeperAdmissionRosterStore()..replace(['alice', 'bob'], 1);
    final gate = Completer<void>();
    var currentKeeper = 'keeper';
    final keeper = KeeperAdmissionController(
      channel: channel,
      keeperIdentity: () => currentKeeper,
      sessionIdentity: 'session',
      rosterStore: store,
      persistRoster: () => gate.future,
    );
    channel.sent.clear();
    keeper.revoke('alice');
    check(keeper.roster).deepEquals(['bob']);
    check(keeper.rosterRevision).equals(1);
    currentKeeper = 'other';
    gate.complete();
    await keeper.pendingRosterWrites;
    check(keeper.rosterRevision).equals(1);
    check(channel.sent.whereType<AdmissionRosterUpdated>()).isEmpty();
    await keeper.dispose();
    await channel.controller.close();
  });

  test(
    'readiness stays hidden until its snapshot persists; failure can retry',
    () async {
      final now = DateTime.utc(2030);
      final channel = _Channel();
      final store = KeeperAdmissionRosterStore(keeperGeneration: 'generation')
        ..replace(['alice'], 3, awaitingReadiness: ['alice']);
      final writes = <Completer<void>>[];
      final captured = <List<String>>[];
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
        now: () => now,
        persistRoster: () {
          captured.add(store.awaitingReadiness.toList());
          final gate = Completer<void>();
          writes.add(gate);
          return gate.future;
        },
      );
      final expiry = now.add(const Duration(minutes: 1));
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'request',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
            displayName: 'Alice',
          ),
        ),
      );
      await Future<void>.value();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionJoined(
            id: 'request',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
          ),
        ),
      );
      check(captured).deepEquals([<String>[]]);
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      check(keeper.roster).isEmpty();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterRequest(
            id: 'snapshot',
            senderIdentity: 'alice',
            recipientIdentity: 'keeper',
            expiresAt: expiry,
            sessionIdentity: 'session',
          ),
        ),
      );
      final snapshot = channel.sent.whereType<AdmissionRosterSnapshot>().last;
      check(snapshot.members).isEmpty();
      check(snapshot.revision).equals(3);
      writes.single.completeError(StateError('disk'));
      await keeper.pendingRosterWrites;
      check(keeper.persistenceError).isA<StateError>();
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      check(keeper.roster).isEmpty();
      final retry = keeper.retryRosterPersistence();
      check(captured).length.equals(2);
      writes.last.complete();
      await retry;
      check(keeper.roster).deepEquals(['alice']);
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
      check(keeper.persistenceError).isNull();
      await keeper.dispose();
      await channel.controller.close();
    },
  );

  test(
    'overlapping writes cannot restore revoked access and dispose drains',
    () async {
      final channel = _Channel();
      final store = KeeperAdmissionRosterStore(keeperGeneration: 'generation')
        ..replace(['alice', 'bob'], 1);
      final writes = <Completer<void>>[];
      final captured = <List<String>>[];
      final keeper =
          KeeperAdmissionController(
              channel: channel,
              keeperIdentity: () => 'keeper',
              sessionIdentity: 'session',
              rosterStore: store,
              persistRoster: () {
                captured.add(store.members.toList());
                final gate = Completer<void>();
                writes.add(gate);
                return gate.future;
              },
            )
            ..revoke('alice')
            ..revoke('bob');
      check(captured).deepEquals([
        ['bob'],
        <String>[],
      ]);
      check(keeper.roster).isEmpty();
      writes[1].complete();
      await Future<void>.value();
      check(keeper.roster).isEmpty();
      final sentBeforeDispose = channel.sent.length;
      var disposed = false;
      final disposal = keeper.dispose().then((_) {
        disposed = true;
      });
      await Future<void>.value();
      check(disposed).isFalse();
      writes[0].complete();
      await disposal;
      check(channel.sent.length).equals(sentBeforeDispose);
      await channel.controller.close();
    },
  );
}
