import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';

class _RoomEvents implements EventsListener<RoomEvent> {
  final handlers = <Type, List<FutureOr<void> Function(Object?)>>{};

  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) handler, {
    bool Function(E)? filter,
  }) {
    handlers.putIfAbsent(E, () => []).add((event) {
      final typed = event as E;
      if (filter == null || filter(typed)) return handler(typed);
    });
    return () async {};
  }

  Future<void> trigger<E>(E event) async {
    for (final handler in handlers[E] ?? <FutureOr<void> Function(Object?)>[]) {
      await handler(event);
    }
  }

  @override
  Future<bool> dispose() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Participant implements LocalParticipant {
  new(this.identity);

  @override
  final String identity;
  final published = <Invocation>[];
  Future<void> Function(Invocation)? onPublish;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #publishData) {
      published.add(invocation);
      return onPublish?.call(invocation) ?? Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _RemoteParticipant implements RemoteParticipant {
  new(this.identity);

  @override
  final String identity;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AdmissionRoom implements Room {
  new(this.metadata);

  @override
  String? metadata;
  _Participant? participant;
  final listener = _RoomEvents();

  @override
  LocalParticipant? get localParticipant => participant;

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = true}) =>
      listener;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel implements AdmissionChannel {
  new(this.localIdentity);

  @override
  final String localIdentity;
  @override
  bool hasEnded = false;
  final controller = StreamController<AdmissionEvent>.broadcast(sync: true);
  final sent = <AdmissionPacket>[];

  final present = <String>{};
  _Channel? peer;
  bool dropNext = false;
  Future<void> Function(AdmissionPacket)? beforeSend;

  @override
  Stream<AdmissionEvent> get events => controller.stream;

  @override
  Iterable<String> get remoteIdentities => present;

  @override
  bool isPresent(String identity) => present.contains(identity);

  @override
  Future<void> send(AdmissionPacket packet) async {
    sent.add(packet);
    final hook = beforeSend;
    if (hook != null) await hook(packet);
    if (dropNext) {
      dropNext = false;
      return;
    }
    final target = peer;
    if (target == null || packet.recipientIdentity != target.localIdentity) {
      return;
    }
    final decoded = AdmissionProtocol.decode(
      AdmissionProtocol.encode(packet),
      senderIdentity: localIdentity,
      now: DateTime.now(),
    );
    if (decoded != null) {
      await Future<void>.value();
      target.controller.add(AdmissionPacketReceived(decoded));
    }
  }

  Future<void> dispose() => controller.close();
}

String _roomMetadata(String status) => jsonEncode({
  'session_slug': 'session',
  'version': 1,
  'status': status,
  'turn_state': 'idle',
  'status_detail': status == 'ended'
      ? {'type': 'ended', 'reason': 'keeper_ended'}
      : {'type': 'active'},
  'talking_order': <String>[],
  'keeper': 'keeper',
  'round_number': 0,
});

void main() {
  test('protocol rejects unknown version, spoofed sender and expired packets', () {
    final now = DateTime.utc(2026);
    final request = AdmissionRequest(
      id: 'id',
      senderIdentity: 'alice',
      recipientIdentity: 'keeper',
      expiresAt: now.add(const Duration(minutes: 2)),
      displayName: 'Alice',
    );
    final payload = AdmissionProtocol.encode(request);
    check(AdmissionProtocol.decode(payload, senderIdentity: 'alice', now: now))
        .isA<AdmissionRequest>();
    check(
      AdmissionProtocol.decode(payload, senderIdentity: 'mallory', now: now),
    ).isNull();
    check(AdmissionProtocol.decode(payload, senderIdentity: null, now: now))
        .isNull();
    check(
      AdmissionProtocol.decode(
        payload,
        senderIdentity: 'alice',
        now: now.add(const Duration(minutes: 2)),
      ),
    ).isNull();
    final cancel = AdmissionCancel(
      id: request.id,
      senderIdentity: request.senderIdentity,
      recipientIdentity: request.recipientIdentity,
      expiresAt: request.expiresAt,
    );
    check(
      AdmissionProtocol.decode(
        AdmissionProtocol.encode(cancel),
        senderIdentity: 'alice',
        now: now,
      ),
    ).isA<AdmissionCancel>();
    check(
      AdmissionProtocol.decode(
        AdmissionProtocol.encode(cancel),
        senderIdentity: 'mallory',
        now: now,
      ),
    ).isNull();
    final hello = AdmissionHello(
      id: 'hello',
      senderIdentity: 'keeper',
      recipientIdentity: 'alice',
      expiresAt: now.subtract(const Duration(days: 1)),
    );
    check(
      AdmissionProtocol.decode(
        AdmissionProtocol.encode(hello),
        senderIdentity: 'keeper',
        now: now,
      ),
    ).isA<AdmissionHello>();
    check(
      AdmissionProtocol.decode(
        AdmissionProtocol.encode(hello),
        senderIdentity: 'mallory',
        now: now,
      ),
    ).isNull();
    final decoded = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    check(
      AdmissionProtocol.decode(
        utf8.encode(jsonEncode({...decoded, 'to': 'x' * 257})),
        senderIdentity: 'alice',
        now: now,
      ),
    ).isNull();
    final oversizedSender = 's' * 257;
    check(
      AdmissionProtocol.decode(
        utf8.encode(jsonEncode({...decoded, 'from': oversizedSender})),
        senderIdentity: oversizedSender,
        now: now,
      ),
    ).isNull();
    check(
      AdmissionProtocol.decode(
        utf8.encode(jsonEncode({...decoded, 'expiresAt': 9223372036854775807})),
        senderIdentity: 'alice',
        now: now,
      ),
    ).isNull();
    check(
      AdmissionProtocol.decode(
        List<int>.filled(AdmissionProtocol.maxPayloadBytes + 1, 97),
        senderIdentity: 'alice',
        now: now,
      ),
    ).isNull();
    check(
      AdmissionProtocol.decode(
        utf8.encode(
          '{"v":2,"kind":"request","id":"id","from":"alice",'
          '"to":"keeper","expiresAt":${request.expiresAt.millisecondsSinceEpoch},'
          '"name":"Alice"}',
        ),
        senderIdentity: 'alice',
        now: now,
      ),
    ).isNull();
  });

  test(
    'transport reads canonical room metadata and emits ended once',
    () async {
      final room = _AdmissionRoom(null);
      final transport = LiveKitAdmissionTransport(room);
      final received = <AdmissionEvent>[];
      final subscription = transport.events.listen(received.add);
      addTearDown(() async {
        await subscription.cancel();
        await transport.dispose();
      });
      await room.listener.trigger(
        const RoomMetadataChangedEvent(metadata: '{invalid'),
      );
      await room.listener.trigger(
        RoomMetadataChangedEvent(metadata: _roomMetadata('active')),
      );
      check(transport.hasEnded).isFalse();
      check(received).isEmpty();
      final ended = _roomMetadata('ended');
      room.metadata = ended;
      await room.listener.trigger(RoomMetadataChangedEvent(metadata: ended));
      await room.listener.trigger(RoomMetadataChangedEvent(metadata: ended));
      check(transport.hasEnded).isTrue();
      check(received).length.equals(1);
      check(received.single).isA<AdmissionRoomEnded>();

      final alreadyEnded = LiveKitAdmissionTransport(_AdmissionRoom(ended));
      check(alreadyEnded.hasEnded).isTrue();
      await alreadyEnded.dispose();
    },
  );

  test(
    'normal-room receipt retries only for authenticated keeper presence',
    () async {
      final room = _AdmissionRoom(null)..participant = _Participant('guest');
      final transport = LiveKitAdmissionTransport(room);
      addTearDown(transport.dispose);
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      await transport.sendJoinOutcome(request);
      check(room.participant!.published).length.equals(1);
      final publication = room.participant!.published.single;
      check(publication.namedArguments[#topic]).equals(AdmissionProtocol.topic);
      check(publication.namedArguments[#destinationIdentities] as List<String>)
          .single
          .equals('keeper');
      check(
        AdmissionProtocol.decode(
          publication.positionalArguments.single as List<int>,
          senderIdentity: 'guest',
          now: DateTime.now(),
        ),
      ).isA<AdmissionJoined>();
      await room.listener.trigger(
        DataReceivedEvent(
          data: AdmissionProtocol.encode(
            AdmissionHello(
              id: 'hello',
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: request.expiresAt,
            ),
          ),
          participant: _RemoteParticipant('mallory'),
          topic: AdmissionProtocol.topic,
        ),
      );
      check(room.participant!.published).length.equals(1);
      await room.listener.trigger(
        DataReceivedEvent(
          data: AdmissionProtocol.encode(
            AdmissionHello(
              id: 'hello',
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: request.expiresAt,
            ),
          ),
          participant: _RemoteParticipant('keeper'),
          topic: AdmissionProtocol.topic,
        ),
      );
      check(room.participant!.published).length.equals(2);
      await room.listener.trigger(const RoomReconnectedEvent());
      check(room.participant!.published).length.equals(3);
      await check(transport.sendJoinOutcome(request)).throws<StateError>();
    },
  );

  test('failed receipt publish retries on recreated Keeper hello', () async {
    final room = _AdmissionRoom(null)..participant = _Participant('guest');
    final transport = LiveKitAdmissionTransport(room);
    final keeperChannel = _Channel('keeper')..present.add('guest');
    addTearDown(() async {
      await transport.dispose();
      await keeperChannel.dispose();
    });
    final request = AdmissionRequest(
      id: 'r1',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      displayName: 'Guest',
    );
    room.participant!.onPublish = (_) async => throw StateError('offline');
    await check(transport.sendJoinOutcome(request)).throws<StateError>();
    room.participant!.onPublish = (invocation) async {
      final packet = AdmissionProtocol.decode(
        invocation.positionalArguments.single as List<int>,
        senderIdentity: 'guest',
        now: DateTime.now(),
      );
      if (packet != null) {
        keeperChannel.controller.add(AdmissionPacketReceived(packet));
      }
    };
    var advertised = Completer<void>();
    keeperChannel.beforeSend = (packet) async {
      if (packet is! AdmissionHello) return;
      await room.listener.trigger(
        DataReceivedEvent(
          data: AdmissionProtocol.encode(packet),
          participant: _RemoteParticipant('keeper'),
          topic: AdmissionProtocol.topic,
        ),
      );
      advertised.complete();
    };
    final keeper = KeeperAdmissionController(
      channel: keeperChannel,
      keeperIdentity: () => 'keeper',
    );
    addTearDown(keeper.dispose);
    await advertised.future;
    check(room.participant!.published).length.equals(2);
    // A recreated Keeper has no decision history: orphaned receipts are ignored.
    check(keeper.attempts).isEmpty();
    await keeper.dispose();

    keeperChannel.present.clear();
    advertised = Completer<void>();
    final nextKeeper = KeeperAdmissionController(
      channel: keeperChannel,
      keeperIdentity: () => 'keeper',
    );
    addTearDown(nextKeeper.dispose);
    check(keeperChannel.sent).length.equals(1);
    keeperChannel.present.add('guest');
    keeperChannel.controller.add(const AdmissionPresenceChanged('guest', true));
    await advertised.future;
    check(room.participant!.published).length.equals(3);
    check(nextKeeper.attempts).isEmpty();
  });

  test('transient reconnect does not emit terminal disconnect', () async {
    final room = _AdmissionRoom(null);
    final transport = LiveKitAdmissionTransport(room);
    final received = <AdmissionEvent>[];
    final subscription = transport.events.listen(received.add);
    addTearDown(() async {
      await subscription.cancel();
      await transport.dispose();
    });
    await room.listener.trigger(const RoomReconnectingEvent());
    await room.listener.trigger(const RoomResumingEvent());
    check(received).isEmpty();
    await room.listener.trigger(const RoomReconnectedEvent());
    check(received.single).isA<AdmissionConnectionRestored>();
    await room.listener.trigger(
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    check(received).length.equals(2);
    check((received.last as AdmissionRoomDisconnected).reason)
        .equals(DisconnectReason.reconnectAttemptsExceeded);
  });

  test('pending fails on terminal disconnect and ends on metadata', () async {
    final channel = _Channel('guest');
    channel.present.add('keeper');
    final guest = PendingAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      newId: () => 'r1',
    );
    addTearDown(() async {
      await guest.dispose();
      await channel.dispose();
    });
    await guest.requestAdmission(displayName: 'Guest');
    channel.controller.add(const AdmissionConnectionRestored());
    check(guest.status).equals(AdmissionStatus.pending);
    final sentBeforeFailure = channel.sent.length;
    channel.controller.add(
      const AdmissionRoomDisconnected(DisconnectReason.roomDeleted),
    );
    check(guest.status).equals(AdmissionStatus.failed);
    channel.controller.add(const AdmissionPresenceChanged('keeper', true));
    check(channel.sent).length.equals(sentBeforeFailure);
    await check(guest.requestAdmission(displayName: 'Guest'))
        .throws<StateError>();
    channel.controller.add(const AdmissionRoomEnded());
    check(guest.status).equals(AdmissionStatus.ended);
  });

  test(
    'metadata end terminates pending admission and notifies listeners',
    () async {
      final channel = _Channel('guest');
      final guest = PendingAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await guest.dispose();
        await channel.dispose();
      });
      final changed = guest.changes.first;
      channel.hasEnded = true;
      channel.controller.add(const AdmissionRoomEnded());
      check(await changed).equals(AdmissionStatus.ended);
      check(guest.status).equals(AdmissionStatus.ended);
      channel.controller.add(
        const AdmissionRoomDisconnected(DisconnectReason.roomDeleted),
      );
      check(guest.status).equals(AdmissionStatus.ended);
      await check(guest.requestAdmission(displayName: 'Guest'))
          .throws<StateError>();
    },
  );

  test(
    'ended metadata clears keeper queue and prevents future decisions',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(request));
      check(keeper.requests).length.equals(1);
      channel.controller.add(const AdmissionRoomEnded());
      check(keeper.requests).isEmpty();
      channel.controller.add(AdmissionPacketReceived(request));
      check(keeper.requests).isEmpty();
      await check(keeper.approve(request.id, 'guest')).throws<StateError>();

      final endedChannel = _Channel('keeper')..hasEnded = true;
      endedChannel.present.add('guest');
      final endedKeeper = KeeperAdmissionController(
        channel: endedChannel,
        keeperIdentity: () => 'keeper',
      );
      final endedGuestChannel = _Channel('guest')..hasEnded = true;
      final endedGuest = PendingAdmissionController(
        channel: endedGuestChannel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await endedKeeper.dispose();
        await endedGuest.dispose();
        await endedChannel.dispose();
        await endedGuestChannel.dispose();
      });
      check(endedChannel.sent).isEmpty();
      check(endedGuest.status).equals(AdmissionStatus.ended);
      await check(endedGuest.requestAdmission(displayName: 'Guest'))
          .throws<StateError>();
    },
  );

  test('keeper attach advertises to already waiting participant after lost request', () async {
    final guestChannel = _Channel('guest');
    final keeperChannel = _Channel('keeper');
    guestChannel.peer = keeperChannel;
    keeperChannel.peer = guestChannel;
    guestChannel.present.add('keeper');
    keeperChannel.present.add('guest');
    final guest = PendingAdmissionController(
      channel: guestChannel,
      keeperIdentity: () => 'keeper',
      newId: () => 'r1',
    );
    final request = await guest.requestAdmission(displayName: 'Guest');
    // No keeper listener existed when the first request was delivered.
    final keeper = KeeperAdmissionController(
      channel: keeperChannel,
      keeperIdentity: () => 'keeper',
    );
    addTearDown(() async {
      await guest.dispose();
      await keeper.dispose();
      await guestChannel.dispose();
      await keeperChannel.dispose();
    });
    await keeper.changes.first;
    check(keeper.requests.single.id).equals(request.id);
    check(guestChannel.sent).length.equals(2);
    check(identical(guestChannel.sent.last, request)).isTrue();
    check(keeperChannel.sent.single).isA<AdmissionHello>();
    check(keeperChannel.sent.single.recipientIdentity).equals('guest');
    keeperChannel.controller.add(const AdmissionConnectionRestored());
    await Future<void>.value();
    check(keeperChannel.sent).length.equals(2);
    check(keeper.requests).length.equals(1);
  });

  test('untrusted keeper hello cannot trigger resend', () async {
    final channel = _Channel('guest');
    channel.present.add('keeper');
    final guest = PendingAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      newId: () => 'r1',
    );
    addTearDown(() async {
      await guest.dispose();
      await channel.dispose();
    });
    await guest.requestAdmission(displayName: 'Guest');
    final sent = channel.sent.length;
    for (final hello in [
      AdmissionHello(
        id: 'h1',
        senderIdentity: 'attacker',
        recipientIdentity: 'guest',
        expiresAt: DateTime.now(),
      ),
      AdmissionHello(
        id: 'h2',
        senderIdentity: 'keeper',
        recipientIdentity: 'other',
        expiresAt: DateTime.now(),
      ),
    ]) {
      channel.controller.add(AdmissionPacketReceived(hello));
    }
    check(channel.sent).length.equals(sent);
    check(guest.status).equals(AdmissionStatus.pending);
  });

  test('presence resend recovers a dropped request, decision is targeted and deduped', () async {
    final guestChannel = _Channel('guest');
    final keeperChannel = _Channel('keeper');
    guestChannel.peer = keeperChannel;
    keeperChannel.peer = guestChannel;
    guestChannel.present.add('keeper');
    final guest = PendingAdmissionController(
      channel: guestChannel,
      keeperIdentity: () => 'keeper',
      newId: () => 'r1',
    );
    final keeper = KeeperAdmissionController(
      channel: keeperChannel,
      keeperIdentity: () => 'keeper',
    );
    keeperChannel.present.add('guest');
    addTearDown(() async {
      await guest.dispose();
      await keeper.dispose();
      await guestChannel.dispose();
      await keeperChannel.dispose();
    });

    guestChannel.dropNext = true;
    final request = await guest.requestAdmission(displayName: 'Guest');
    check(guest.status).equals(AdmissionStatus.pending);
    check(keeper.requests).isEmpty();

    final requestArrived = keeper.changes.first;
    guestChannel.controller.add(const AdmissionConnectionRestored());
    await requestArrived;
    check(keeper.requests).length.equals(1);
    check(guestChannel.sent).length.equals(2);
    check(identical(guestChannel.sent.last, request)).isTrue();

    keeperChannel.dropNext = true;
    await keeper.approve(request.id, 'guest');
    check(guest.status).equals(AdmissionStatus.pending);
    check(keeper.requests).isEmpty();
    final approved = guest.changes.firstWhere(
      (status) => status == AdmissionStatus.approved,
    );
    guestChannel.controller.add(const AdmissionPresenceChanged('keeper', true));
    await approved;
    check(guestChannel.sent).length.equals(3);
    check(keeperChannel.sent).length.equals(2);
    check(guest.status).equals(AdmissionStatus.approved);
    check((keeperChannel.sent.last as AdmissionDecision).approved).isTrue();
    check(keeperChannel.sent.last.recipientIdentity).equals('guest');

    guestChannel.controller.add(
      AdmissionPacketReceived(
        AdmissionDecision(
          id: request.id,
          senderIdentity: 'keeper',
          recipientIdentity: 'guest',
          expiresAt: request.expiresAt,
          approved: false,
        ),
      ),
    );
    check(guest.status).equals(AdmissionStatus.approved);
  });

  test(
    'keeper rejects non-keeper authority and expired or changed requests',
    () async {
      final channel = _Channel('keeper');
      var keeperIdentity = 'other';
      var now = DateTime.utc(2026);
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => keeperIdentity,
        now: () => now,
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: now.add(const Duration(minutes: 2)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(request));
      check(keeper.requests).isEmpty();
      keeperIdentity = 'keeper';
      channel.controller.add(AdmissionPacketReceived(request));
      check(keeper.requests).length.equals(1);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'r1',
            senderIdentity: 'guest',
            recipientIdentity: 'keeper',
            expiresAt: now.add(const Duration(minutes: 1)),
            displayName: 'Other',
          ),
        ),
      );
      check(keeper.requests.single.displayName).equals('Guest');
      now = now.add(const Duration(minutes: 2));
      await check(keeper.deny('r1', 'guest')).throws<StateError>();
    },
  );

  test(
    'request waits for keeper presence and expires without polling',
    () async {
      final channel = _Channel('guest');
      var now = DateTime.now();
      final guest = PendingAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        now: () => now,
        newId: () => 'r1',
      );
      addTearDown(() async {
        await guest.dispose();
        await channel.dispose();
      });
      await guest.requestAdmission(displayName: 'Guest');
      check(channel.sent).isEmpty();
      channel.present.add('keeper');
      channel.controller.add(const AdmissionPresenceChanged('keeper', true));
      check(channel.sent).length.equals(1);
      now = now.add(AdmissionProtocol.lifetime);
      channel.controller.add(const AdmissionConnectionRestored());
      check(guest.status).equals(AdmissionStatus.expired);
      check(channel.sent).length.equals(1);
    },
  );

  test(
    'failed initial send stays pending and resends on keeper presence',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      guestChannel.peer = keeperChannel;
      guestChannel.present.add('keeper');
      final guest = PendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final keeper = KeeperAdmissionController(
        channel: keeperChannel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await guest.dispose();
        await keeper.dispose();
        await guestChannel.dispose();
        await keeperChannel.dispose();
      });
      guestChannel.beforeSend = (_) async => throw StateError('offline');
      final request = await guest.requestAdmission(displayName: 'Guest');
      check(guest.status).equals(AdmissionStatus.pending);
      check(keeper.requests).isEmpty();
      guestChannel.controller.add(const AdmissionConnectionRestored());
      check(guest.status).equals(AdmissionStatus.pending);
      check(keeper.requests).isEmpty();
      guestChannel.beforeSend = null;
      final arrived = keeper.changes.first;
      guestChannel.controller.add(
        const AdmissionPresenceChanged('keeper', true),
      );
      await arrived;
      check(keeper.requests.single.id).equals(request.id);
      check(guestChannel.sent).length.equals(3);
    },
  );

  test(
    'cancel is targeted, terminal locally, and prevents request replay',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      guestChannel.peer = keeperChannel;
      guestChannel.present.add('keeper');
      final guest = PendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final keeper = KeeperAdmissionController(
        channel: keeperChannel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await guest.dispose();
        await keeper.dispose();
        await guestChannel.dispose();
        await keeperChannel.dispose();
      });
      final request = await guest.requestAdmission(displayName: 'Guest');
      check(keeper.requests).length.equals(1);
      await guest.cancel();
      check(guest.status).equals(AdmissionStatus.cancelled);
      guestChannel.controller.add(
        const AdmissionRoomDisconnected(DisconnectReason.clientInitiated),
      );
      check(guest.status).equals(AdmissionStatus.cancelled);
      check(keeper.requests).isEmpty();
      check(guestChannel.sent.last).isA<AdmissionCancel>();
      check(guestChannel.sent.last.recipientIdentity).equals('keeper');
      keeperChannel.controller.add(AdmissionPacketReceived(request));
      check(keeper.requests).isEmpty();
      guestChannel.controller.add(
        AdmissionPacketReceived(
          AdmissionDecision(
            id: request.id,
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: request.expiresAt,
            approved: true,
          ),
        ),
      );
      check(guest.status).equals(AdmissionStatus.cancelled);
    },
  );

  test(
    'failed cancel resends on reconnect, including cancel before request',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      guestChannel.peer = keeperChannel;
      guestChannel.present.add('keeper');
      final guest = PendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final keeper = KeeperAdmissionController(
        channel: keeperChannel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await guest.dispose();
        await keeper.dispose();
        await guestChannel.dispose();
        await keeperChannel.dispose();
      });
      guestChannel.dropNext = true;
      final request = await guest.requestAdmission(displayName: 'Guest');
      guestChannel.beforeSend = (_) async => throw StateError('offline');
      await guest.cancel();
      check(guest.status).equals(AdmissionStatus.cancelled);
      guestChannel.beforeSend = null;
      final changed = keeper.changes.first;
      guestChannel.controller.add(const AdmissionConnectionRestored());
      await changed;
      check(keeper.requests).isEmpty();
      keeperChannel.controller.add(AdmissionPacketReceived(request));
      check(keeper.requests).isEmpty();
    },
  );

  test(
    'disconnect removes queue; resend restores it, not a superseded ID',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final expiration = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );
      AdmissionRequest request(String id, DateTime expiresAt, String sender) =>
          AdmissionRequest(
            id: id,
            senderIdentity: sender,
            recipientIdentity: 'keeper',
            expiresAt: expiresAt,
            displayName: sender,
          );
      final old = request('old', expiration, 'guest');
      final current = request(
        'new',
        expiration.add(const Duration(milliseconds: 1)),
        'guest',
      );
      channel.controller.add(AdmissionPacketReceived(old));
      channel.controller.add(const AdmissionPresenceChanged('guest', false));
      check(keeper.requests).isEmpty();
      channel.controller.add(AdmissionPacketReceived(old));
      check(keeper.requests.single.id).equals('old');
      channel.controller.add(AdmissionPacketReceived(current));
      channel.controller.add(AdmissionPacketReceived(old));
      channel.controller.add(
        AdmissionPacketReceived(request('self', expiration, 'keeper')),
      );
      check(keeper.requests.single.id).equals('new');
      channel.controller.add(const AdmissionPresenceChanged('guest', false));
      channel.controller.add(AdmissionPacketReceived(current));
      check(keeper.requests.single.id).equals('new');
    },
  );

  test(
    'back-to-back requests have ordered expirations and reject old replay',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      final fixedNow = DateTime.now();
      var nextId = 0;
      final guest = PendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        now: () => fixedNow,
        newId: () => 'r${++nextId}',
      );
      final keeper = KeeperAdmissionController(
        channel: keeperChannel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await guest.dispose();
        await keeper.dispose();
        await guestChannel.dispose();
        await keeperChannel.dispose();
      });
      final old = await guest.requestAdmission(displayName: 'Guest');
      await guest.cancel();
      final current = await guest.requestAdmission(displayName: 'Guest');
      check(current.expiresAt.isAfter(old.expiresAt)).isTrue();
      keeperChannel.controller.add(AdmissionPacketReceived(current));
      keeperChannel.controller.add(AdmissionPacketReceived(old));
      check(keeper.requests.single.id).equals(current.id);
    },
  );

  test(
    'decision send failure retains queue and blocks simultaneous decisions',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(request));
      final gate = Completer<void>();
      channel.beforeSend = (_) => gate.future;
      final attempt = keeper.approve('r1', 'guest');
      check(keeper.requests).length.equals(1);
      await check(keeper.deny('r1', 'guest')).throws<StateError>();
      gate.completeError(StateError('send failed'));
      await check(attempt).throws<StateError>();
      check(keeper.requests).length.equals(1);
      channel.beforeSend = null;
      await keeper.deny('r1', 'guest');
      check(keeper.requests).isEmpty();
      channel.controller.add(AdmissionPacketReceived(request));
      check(channel.sent).length.equals(3);
      check((channel.sent.last as AdmissionDecision).approved).isFalse();
    },
  );

  test(
    'older in-flight decision cannot remove or answer newer request',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final expiration = DateTime.now().add(const Duration(minutes: 1));
      AdmissionRequest request(String id, DateTime expiresAt) =>
          AdmissionRequest(
            id: id,
            senderIdentity: 'guest',
            recipientIdentity: 'keeper',
            expiresAt: expiresAt,
            displayName: 'Guest',
          );
      final old = request('old', expiration);
      final current = request(
        'new',
        expiration.add(const Duration(milliseconds: 1)),
      );
      channel.controller.add(AdmissionPacketReceived(old));
      final gate = Completer<void>();
      channel.beforeSend = (packet) =>
          packet.id == 'old' ? gate.future : Future<void>.value();
      final oldAttempt = keeper.approve('old', 'guest');
      channel.controller.add(AdmissionPacketReceived(current));
      await keeper.deny('new', 'guest');
      gate.complete();
      await check(oldAttempt).throws<StateError>();
      check(keeper.requests).isEmpty();
      channel.controller.add(AdmissionPacketReceived(old));
      channel.controller.add(AdmissionPacketReceived(current));
      check(channel.sent.last.id).equals('new');
      check((channel.sent.last as AdmissionDecision).approved).isFalse();
    },
  );

  test(
    'join receipts require authenticated sender and live attempt fields',
    () {
      final now = DateTime.utc(2026);
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: now.add(AdmissionProtocol.lifetime),
        displayName: 'Guest',
      );
      for (final receipt in [
        AdmissionProtocol.joined(request),
        AdmissionProtocol.joinFailed(request),
      ]) {
        final bytes = AdmissionProtocol.encode(receipt);
        check(
          AdmissionProtocol.decode(bytes, senderIdentity: 'guest', now: now),
        ).isA<AdmissionPacket>();
        check(
          AdmissionProtocol.decode(bytes, senderIdentity: 'mallory', now: now),
        ).isNull();
        check(
          AdmissionProtocol.decode(
            bytes,
            senderIdentity: 'guest',
            now: request.expiresAt,
          ),
        ).isNull();
        final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        check(data['kind']).equals(
          receipt is AdmissionJoined
              ? 'admission.joined'
              : 'admission.joinFailed',
        );
        for (final invalid in [
          {...data, 'id': ''},
          {...data, 'to': ''},
          {
            ...data,
            'expiresAt': now
                .add(const Duration(minutes: 3))
                .millisecondsSinceEpoch,
          },
          {...data, 'approved': true},
        ]) {
          check(
            AdmissionProtocol.decode(
              utf8.encode(jsonEncode(invalid)),
              senderIdentity: 'guest',
              now: now,
            ),
          ).isNull();
        }
      }
    },
  );

  test(
    'keeper waits for joined receipt and ignores wrong or late outcomes',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      final receipt = AdmissionProtocol.joined(request);
      channel.controller.add(AdmissionPacketReceived(receipt));
      check(keeper.attempts).isEmpty();
      channel.controller.add(AdmissionPacketReceived(request));
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.requested);
      channel.controller.add(AdmissionPacketReceived(receipt));
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.requested);
      await keeper.approve(request.id, 'guest');
      check(keeper.requests).isEmpty();
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.joining);
      check(keeper.attempts.single.joinDeadline).equals(request.expiresAt);
      channel.controller.add(AdmissionPacketReceived(request));
      await Future<void>.value();
      check(channel.sent).length.equals(2);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionJoined(
            id: 'wrong',
            senderIdentity: 'guest',
            recipientIdentity: 'keeper',
            expiresAt: request.expiresAt,
          ),
        ),
      );
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionJoined(
            id: request.id,
            senderIdentity: 'mallory',
            recipientIdentity: 'keeper',
            expiresAt: request.expiresAt,
          ),
        ),
      );
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionJoined(
            id: request.id,
            senderIdentity: 'guest',
            recipientIdentity: 'keeper',
            expiresAt: request.expiresAt.add(const Duration(milliseconds: 1)),
          ),
        ),
      );
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.joining);
      channel.controller.add(AdmissionPacketReceived(receipt));
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joinFailed(request)),
      );
      channel.controller.add(AdmissionPacketReceived(receipt));
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionCancel(
            id: request.id,
            senderIdentity: 'guest',
            recipientIdentity: 'keeper',
            expiresAt: request.expiresAt,
          ),
        ),
      );
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
      channel.controller.add(AdmissionPacketReceived(receipt));
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
    },
  );

  test(
    'receipt arriving during approval send is applied after approval',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(request));
      channel.beforeSend = (_) async => channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(request)),
      );
      await keeper.approve(request.id, 'guest');
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
    },
  );

  test(
    'disconnect during approval still accepts the normal-room receipt',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(request));
      final sent = Completer<void>();
      channel.beforeSend = (_) => sent.future;
      final approval = keeper.approve(request.id, 'guest');
      channel.controller.add(const AdmissionPresenceChanged('guest', false));
      check(keeper.requests).isEmpty();
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(request)),
      );
      sent.complete();
      await approval;
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
      check(keeper.requests).isEmpty();
    },
  );

  test(
    'failed decision after disconnect does not leave a ghost attempt',
    () async {
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(request));
      final sent = Completer<void>();
      channel.beforeSend = (_) => sent.future;
      final approval = keeper.approve(request.id, 'guest');
      channel.controller.add(const AdmissionPresenceChanged('guest', false));
      sent.completeError(StateError('offline'));
      await check(approval).throws<StateError>();
      check(keeper.attempts).isEmpty();
      check(keeper.requests).isEmpty();
      channel.controller.add(AdmissionPacketReceived(request));
      check(keeper.requests.single.id).equals(request.id);
    },
  );

  test('join failure, cancel, end and expiry remain visible to keeper', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026);
      final clock = async.getClock(start);
      final channel = _Channel('keeper');
      final keeper = KeeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        now: clock.now,
      );
      AdmissionRequest request(String id, DateTime expiry) => AdmissionRequest(
        id: id,
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: expiry,
        displayName: 'Guest',
      );
      final first = request('first', start.add(const Duration(seconds: 30)));
      channel.controller.add(AdmissionPacketReceived(first));
      unawaited(keeper.approve(first.id, 'guest'));
      async.flushMicrotasks();
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joinFailed(first)),
      );
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.joinFailed);
      final second = request('second', start.add(const Duration(seconds: 31)));
      channel.controller.add(AdmissionPacketReceived(second));
      unawaited(keeper.approve(second.id, 'guest'));
      async.flushMicrotasks();
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.joining);
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(first)),
      );
      check(keeper.attempts.single.request.id).equals(second.id);
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.joining);
      async.elapse(const Duration(seconds: 31));
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.timedOut);
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(second)),
      );
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.timedOut);
      final third = request('third', start.add(const Duration(seconds: 90)));
      channel.controller.add(AdmissionPacketReceived(third));
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionCancel(
            id: third.id,
            senderIdentity: 'guest',
            recipientIdentity: 'keeper',
            expiresAt: third.expiresAt,
          ),
        ),
      );
      check(keeper.attempts.single.status)
          .equals(KeeperAdmissionStatus.cancelled);
      channel.controller.add(AdmissionPacketReceived(third));
      check(keeper.requests).isEmpty();
      channel.controller.add(const AdmissionRoomEnded());
      check(keeper.attempts).isEmpty();
      unawaited(keeper.dispose());
      unawaited(channel.dispose());
      async.flushMicrotasks();
    });
  });

  test(
    'pending participant ignores decisions from the wrong keeper or request',
    () async {
      final channel = _Channel('guest');
      channel.present.add('keeper');
      final guest = PendingAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      addTearDown(() async {
        await guest.dispose();
        await channel.dispose();
      });
      final request = await guest.requestAdmission(displayName: 'Guest');
      for (final decision in [
        AdmissionDecision(
          id: 'other',
          senderIdentity: 'keeper',
          recipientIdentity: 'guest',
          expiresAt: request.expiresAt,
          approved: true,
        ),
        AdmissionDecision(
          id: 'r1',
          senderIdentity: 'mallory',
          recipientIdentity: 'guest',
          expiresAt: request.expiresAt,
          approved: true,
        ),
      ]) {
        channel.controller.add(AdmissionPacketReceived(decision));
      }
      check(guest.status).equals(AdmissionStatus.pending);
    },
  );
}
