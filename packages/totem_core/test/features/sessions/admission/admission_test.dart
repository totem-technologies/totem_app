import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_join_receipt.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

final _fixedNow = DateTime.utc(2030);

DateTime _testNow() => _fixedNow;

PendingAdmissionController _pendingAdmissionController({
  required AdmissionChannel channel,
  required String Function() keeperIdentity,
  DateTime Function()? now,
  String Function()? newId,
}) => PendingAdmissionController(
  channel: channel,
  keeperIdentity: keeperIdentity,
  now: now ?? _testNow,
  newId: newId,
);

KeeperAdmissionController _keeperAdmissionController({
  required AdmissionChannel channel,
  required String Function() keeperIdentity,
  String? sessionIdentity,
  String? keeperGeneration,
  KeeperAdmissionRosterStore? rosterStore,
  bool approvalRequired = true,
  bool Function()? isSessionStarted,
  Set<String> declinedIdentities = const {},
  DateTime Function()? now,
  String Function()? newId,
}) => KeeperAdmissionController(
  channel: channel,
  keeperIdentity: keeperIdentity,
  sessionIdentity: sessionIdentity,
  keeperGeneration: keeperGeneration,
  rosterStore: rosterStore,
  approvalRequired: approvalRequired,
  isSessionStarted: isSessionStarted,
  declinedIdentities: declinedIdentities,
  now: now ?? _testNow,
  newId: newId,
);

ClientAdmissionRosterController _clientAdmissionRosterController({
  required AdmissionChannel channel,
  required String Function() keeperIdentity,
  required String sessionIdentity,
  DateTime Function()? now,
  String Function()? newId,
}) => ClientAdmissionRosterController(
  channel: channel,
  keeperIdentity: keeperIdentity,
  sessionIdentity: sessionIdentity,
  now: now ?? _testNow,
  newId: newId,
);

LiveKitAdmissionTransport _admissionTransport(
  Room room, {
  DateTime Function()? now,
}) => LiveKitAdmissionTransport(room, now: now ?? _testNow);

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
  _Participant(this.identity);

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
  _RemoteParticipant(this.identity);

  @override
  final String identity;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AdmissionRoom implements Room {
  _AdmissionRoom(this.metadata);

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
  _Channel(this.localIdentity, {DateTime Function()? now})
    : _now = now ?? _testNow;

  final DateTime Function() _now;
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
      now: target._now(),
    );
    if (decoded != null) {
      await Future<void>.value();
      target.controller.add(AdmissionPacketReceived(decoded));
    }
  }

  Future<void> dispose() => controller.close();
}

class _RosterRetryHarness {
  _RosterRetryHarness(this.async) {
    final clock = async.getClock(DateTime.utc(2026));
    now = clock.now;
    channel = _Channel('guest', now: now)..present.add('keeper');
    client = _clientAdmissionRosterController(
      channel: channel,
      keeperIdentity: () => keeper,
      sessionIdentity: 'session',
      now: now,
      newId: () => 'request-${++nextId}',
    );
    async.flushMicrotasks();
  }

  final FakeAsync async;
  late final DateTime Function() now;
  late final _Channel channel;
  late final ClientAdmissionRosterController client;
  String keeper = 'keeper';
  int nextId = 0;

  List<AdmissionRosterRequest> get requests =>
      channel.sent.whereType<AdmissionRosterRequest>().toList();

  Duration waitForRequest(int count) {
    var elapsed = Duration.zero;
    while (requests.length < count && elapsed < const Duration(minutes: 5)) {
      const step = Duration(milliseconds: 100);
      async.elapse(step);
      elapsed += step;
    }
    check(requests.length).equals(count);
    return elapsed;
  }

  void snapshot(AdmissionRosterRequest request, {String? sender}) {
    channel.controller.add(
      AdmissionPacketReceived(
        AdmissionRosterSnapshot(
          id: 'snapshot-${request.id}',
          requestId: request.id,
          senderIdentity: sender ?? request.recipientIdentity,
          recipientIdentity: 'guest',
          expiresAt: now().add(const Duration(minutes: 1)),
          sessionIdentity: 'session',
          keeperGeneration: 'generation',
          revision: 1,
          members: const ['guest'],
        ),
      ),
    );
    async.flushMicrotasks();
  }

  void close() {
    unawaited(client.dispose());
    unawaited(channel.dispose());
    async.flushMicrotasks();
  }
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
  test('decision returning metadata is optional and round trips', () {
    for (final returning in [false, true]) {
      final decision = AdmissionDecision(
        id: 'request',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
        approved: true,
        isReturningParticipant: returning,
      );
      final bytes = AdmissionProtocol.encode(decision);
      final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      check(payload.containsKey('returning')).equals(returning);
      if (returning) check(payload['returning']).equals(true);
      final decoded =
          AdmissionProtocol.decode(
                bytes,
                senderIdentity: 'keeper',
                now: _fixedNow,
              )!
              as AdmissionDecision;
      check(decoded.isReturningParticipant).equals(returning);
    }
  });

  test('session start metadata is optional and round trips', () {
    for (final started in <bool?>[null, false, true]) {
      final decision = AdmissionDecision(
        id: 'request',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
        approved: true,
        sessionStartedAtAdmission: started,
      );
      final bytes = AdmissionProtocol.encode(decision);
      final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      check(payload.containsKey('sessionStarted')).equals(started != null);
      if (started != null) check(payload['sessionStarted']).equals(started);
      final decoded =
          AdmissionProtocol.decode(
                bytes,
                senderIdentity: 'keeper',
                now: _fixedNow,
              )!
              as AdmissionDecision;
      check(decoded.sessionStartedAtAdmission).equals(started);
    }
  });

  for (final startedAtApproval in [false, true]) {
    test(
      'keeper samples session start at approval: $startedAtApproval',
      () async {
        final guestChannel = _Channel('guest')..present.add('keeper');
        final keeperChannel = _Channel('keeper')..present.add('guest');
        guestChannel.peer = keeperChannel;
        keeperChannel.peer = guestChannel;
        var started = !startedAtApproval;
        var reads = 0;
        final guest = _pendingAdmissionController(
          channel: guestChannel,
          keeperIdentity: () => 'keeper',
        );
        final keeper = _keeperAdmissionController(
          channel: keeperChannel,
          keeperIdentity: () => 'keeper',
          isSessionStarted: () {
            reads++;
            return started;
          },
        );
        addTearDown(() async {
          await guest.dispose();
          await keeper.dispose();
          await guestChannel.dispose();
          await keeperChannel.dispose();
        });
        final request = await guest.requestAdmission(displayName: 'Guest');
        await pumpEventQueue();
        check(reads).equals(0);
        started = startedAtApproval;
        await keeper.approve(request.id, 'guest');
        await pumpEventQueue();
        check(reads).equals(1);
        check(guest.status).equals(AdmissionStatus.approved);
        check(guest.sessionStartedAtAdmission).equals(startedAtApproval);
      },
    );
  }

  test(
    'pending admission only accepts returning metadata from a trusted approval',
    () async {
      final channel = _Channel('guest');
      final guest = _pendingAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await guest.dispose();
        await channel.dispose();
      });
      final request = await guest.requestAdmission(displayName: 'Guest');
      check(guest.isReturningParticipant).isFalse();
      for (final decision in [
        AdmissionDecision(
          id: request.id,
          senderIdentity: 'attacker',
          recipientIdentity: 'guest',
          expiresAt: request.expiresAt,
          approved: true,
          isReturningParticipant: true,
          sessionStartedAtAdmission: true,
        ),
        AdmissionDecision(
          id: 'other-request',
          senderIdentity: 'keeper',
          recipientIdentity: 'guest',
          expiresAt: request.expiresAt,
          approved: true,
          isReturningParticipant: true,
          sessionStartedAtAdmission: true,
        ),
      ]) {
        channel.controller.add(AdmissionPacketReceived(decision));
        check(guest.status).equals(AdmissionStatus.pending);
        check(guest.isReturningParticipant).isFalse();
        check(guest.sessionStartedAtAdmission).isNull();
      }
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionDecision(
            id: request.id,
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: request.expiresAt,
            approved: true,
            isReturningParticipant: true,
            sessionStartedAtAdmission: true,
          ),
        ),
      );
      check(guest.status).equals(AdmissionStatus.approved);
      check(guest.isReturningParticipant).isTrue();
      check(guest.sessionStartedAtAdmission).equals(true);

      final next = await guest.requestAdmission(displayName: 'Guest');
      check(guest.isReturningParticipant).isFalse();
      check(guest.sessionStartedAtAdmission).isNull();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionDecision(
            id: next.id,
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: next.expiresAt,
            approved: false,
            isReturningParticipant: true,
            sessionStartedAtAdmission: true,
          ),
        ),
      );
      check(guest.status).equals(AdmissionStatus.denied);
      check(guest.isReturningParticipant).isFalse();
      check(guest.sessionStartedAtAdmission).isNull();
    },
  );

  test('protocol rejects unknown version and spoofed sender', () {
    final now = DateTime.utc(2026);
    final request = AdmissionRequest(
      id: 'id',
      senderIdentity: 'alice',
      recipientIdentity: 'keeper',
      expiresAt: now.add(const Duration(minutes: 2)),
      displayName: 'Alice',
    );
    final payload = AdmissionProtocol.encode(request);
    check(
      AdmissionProtocol.decode(payload, senderIdentity: 'alice', now: now),
    ).isA<AdmissionRequest>();
    final sessionRequest = AdmissionRequest(
      id: 'session-request',
      senderIdentity: 'alice',
      recipientIdentity: 'keeper',
      expiresAt: now.add(AdmissionProtocol.requestLifetime),
      displayName: 'Alice',
    );
    check(
      AdmissionProtocol.decode(
        AdmissionProtocol.encode(sessionRequest),
        senderIdentity: 'alice',
        now: now.add(const Duration(minutes: 3)),
      ),
    ).isA<AdmissionRequest>();
    check(
      AdmissionProtocol.decode(payload, senderIdentity: 'mallory', now: now),
    ).isNull();
    check(
      AdmissionProtocol.decode(payload, senderIdentity: null, now: now),
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
      final transport = _admissionTransport(room);
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

      final alreadyEnded = _admissionTransport(_AdmissionRoom(ended));
      check(alreadyEnded.hasEnded).isTrue();
      await alreadyEnded.dispose();
    },
  );

  test(
    'confirmed normal-room receipts do not retry for keeper signals',
    () async {
      final room = _AdmissionRoom(null)..participant = _Participant('guest');
      final transport = _admissionTransport(room);
      addTearDown(transport.dispose);
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      await transport.sendJoinOutcome(request);
      check(room.participant!.published).length.equals(1);
      final publication = room.participant!.published.single;
      check(publication.namedArguments[#topic]).equals(AdmissionProtocol.topic);
      check(
        publication.namedArguments[#destinationIdentities] as List<String>,
      ).single.equals('keeper');
      check(
        AdmissionProtocol.decode(
          publication.positionalArguments.single as List<int>,
          senderIdentity: 'guest',
          now: _fixedNow,
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
      final roster = AdmissionRosterUpdated(
        id: 'roster',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: request.expiresAt,
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: 1,
        members: const ['guest'],
      );
      await room.listener.trigger(
        DataReceivedEvent(
          data: AdmissionProtocol.encode(roster),
          participant: _RemoteParticipant('mallory'),
          topic: AdmissionProtocol.topic,
        ),
      );
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
      await room.listener.trigger(
        DataReceivedEvent(
          data: AdmissionProtocol.encode(roster),
          participant: _RemoteParticipant('keeper'),
          topic: AdmissionProtocol.topic,
        ),
      );
      await room.listener.trigger(
        ParticipantConnectedEvent(participant: _RemoteParticipant('keeper')),
      );
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
      await room.listener.trigger(const RoomReconnectedEvent());
      check(room.participant!.published).length.equals(2);
      await check(transport.sendJoinOutcome(request)).throws<StateError>();
    },
  );

  test('failed receipt publish retries on recreated Keeper hello', () async {
    final room = _AdmissionRoom(null)..participant = _Participant('guest');
    final transport = _admissionTransport(room);
    final keeperChannel = _Channel('keeper')..present.add('guest');
    addTearDown(() async {
      await transport.dispose();
      await keeperChannel.dispose();
    });
    final request = AdmissionRequest(
      id: 'r1',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: _fixedNow.add(const Duration(minutes: 1)),
      displayName: 'Guest',
    );
    room.participant!.onPublish = (_) async => throw StateError('offline');
    await check(transport.sendJoinOutcome(request)).throws<StateError>();
    room.participant!.onPublish = (invocation) async {
      final packet = AdmissionProtocol.decode(
        invocation.positionalArguments.single as List<int>,
        senderIdentity: 'guest',
        now: _fixedNow,
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
    final keeper = _keeperAdmissionController(
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
    final nextKeeper = _keeperAdmissionController(
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

  test(
    'a missed joined receipt retries with bounded backoff until confirmed',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        final room = _AdmissionRoom(null)..participant = _Participant('guest');
        final transport = _admissionTransport(room, now: clock.now);
        final request = AdmissionRequest(
          id: 'r1',
          senderIdentity: 'guest',
          recipientIdentity: 'keeper',
          expiresAt: clock.now().add(const Duration(minutes: 1)),
          displayName: 'Guest',
        );
        unawaited(transport.sendJoinOutcome(request));
        async.flushMicrotasks();
        check(room.participant!.published).length.equals(1);

        async
          ..elapse(const Duration(seconds: 3))
          ..flushMicrotasks();
        check(room.participant!.published).length.equals(2);
        async
          ..elapse(const Duration(seconds: 5))
          ..flushMicrotasks();
        check(room.participant!.published).length.equals(3);
        for (final published in room.participant!.published) {
          final packet = AdmissionProtocol.decode(
            published.positionalArguments.single as List<int>,
            senderIdentity: 'guest',
            now: clock.now(),
          );
          check(packet)
              .isA<AdmissionJoined>()
              .has((receipt) => receipt.id, 'id')
              .equals('r1');
        }

        unawaited(
          room.listener.trigger(
            DataReceivedEvent(
              data: AdmissionProtocol.encode(
                AdmissionRosterUpdated(
                  id: 'roster',
                  senderIdentity: 'keeper',
                  recipientIdentity: 'guest',
                  expiresAt: request.expiresAt,
                  sessionIdentity: 'session',
                  keeperGeneration: 'generation',
                  revision: 1,
                  members: const ['guest'],
                ),
              ),
              participant: _RemoteParticipant('keeper'),
              topic: AdmissionProtocol.topic,
            ),
          ),
        );
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 1));
        check(room.participant!.published).length.equals(3);
        unawaited(transport.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'joined receipt retries pause for reconnect and resume after recovery',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        final room = _AdmissionRoom(null)..participant = _Participant('guest');
        final transport = _admissionTransport(room, now: clock.now);
        final request = AdmissionRequest(
          id: 'r1',
          senderIdentity: 'guest',
          recipientIdentity: 'keeper',
          expiresAt: clock.now().add(const Duration(minutes: 1)),
          displayName: 'Guest',
        );
        unawaited(transport.sendJoinOutcome(request));
        async.flushMicrotasks();
        unawaited(room.listener.trigger(const RoomReconnectingEvent()));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 10));
        check(room.participant!.published).length.equals(1);

        unawaited(room.listener.trigger(const RoomReconnectedEvent()));
        async.flushMicrotasks();
        check(room.participant!.published).length.equals(2);
        unawaited(transport.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'expired confirmation requests a fresh decision before another receipt',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        final sent = <AdmissionPacket>[];
        var failed = false;
        final receipt = AdmissionJoinReceipt(
          localIdentity: () => 'guest',
          send: (packet) async {
            sent.add(packet);
          },
          now: clock.now,
          newId: () => 'fresh',
          onConfirmationFailed: () => failed = true,
        );
        final request = AdmissionRequest(
          id: 'original',
          senderIdentity: 'guest',
          recipientIdentity: 'keeper',
          expiresAt: clock.now().add(const Duration(seconds: 5)),
          displayName: 'Guest',
        );
        unawaited(receipt.sendOutcome(request));
        async.elapse(const Duration(seconds: 6));
        final renewal = sent.whereType<AdmissionRequest>().single;
        check(renewal.id).equals('fresh');
        check(
          sent.whereType<AdmissionJoined>().every(
            (packet) => packet.id == 'original',
          ),
        ).isTrue();
        receipt.handle(
          AdmissionPacketReceived(
            AdmissionDecision(
              id: renewal.id,
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: renewal.expiresAt,
              approved: true,
            ),
          ),
        );
        async.flushMicrotasks();
        check(sent.whereType<AdmissionJoined>().last.id).equals('fresh');
        check(failed).isFalse();
        receipt.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test('disposing during a joined receipt send prevents later retries', () {
    fakeAsync((async) {
      final clock = async.getClock(_fixedNow);
      final send = Completer<void>();
      var sends = 0;
      final receipt = AdmissionJoinReceipt(
        localIdentity: () => 'guest',
        send: (_) {
          sends++;
          return send.future;
        },
        now: clock.now,
      );
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: clock.now().add(const Duration(minutes: 2)),
        displayName: 'Guest',
      );
      unawaited(receipt.sendOutcome(request));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 1));
      check(sends).equals(1);
      receipt.dispose();
      send.complete();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 1));
      check(sends).equals(1);
      check(async.pendingTimers).isEmpty();
    });
  });

  test(
    'duplicate joined receipt resends a committed roster without mutation',
    () async {
      final channel = _Channel('keeper')..present.add('guest');
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(request));
      await keeper.approve(request.id, 'guest');
      final receipt = AdmissionProtocol.joined(request);
      channel.controller.add(AdmissionPacketReceived(receipt));
      await pumpEventQueue();
      final revision = keeper.rosterRevision;
      final snapshots = channel.sent
          .whereType<AdmissionRosterSnapshot>()
          .length;

      channel.controller.add(AdmissionPacketReceived(receipt));
      await pumpEventQueue();

      check(keeper.roster).deepEquals(['guest']);
      check(keeper.rosterRevision).equals(revision);
      check(
        channel.sent.whereType<AdmissionRosterSnapshot>(),
      ).length.equals(snapshots + 1);
    },
  );

  test('admitted roster arriving during publish prevents a receipt retry', () {
    fakeAsync((async) {
      final clock = async.getClock(_fixedNow);
      final room = _AdmissionRoom(null)..participant = _Participant('guest');
      final publishGate = Completer<void>();
      room.participant!.onPublish = (_) => publishGate.future;
      final transport = _admissionTransport(room, now: clock.now);
      final request = AdmissionRequest(
        id: 'r1',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: clock.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      unawaited(transport.sendJoinOutcome(request));
      async.flushMicrotasks();
      unawaited(
        room.listener.trigger(
          DataReceivedEvent(
            data: AdmissionProtocol.encode(
              AdmissionRosterUpdated(
                id: 'roster',
                senderIdentity: 'keeper',
                recipientIdentity: 'guest',
                expiresAt: request.expiresAt,
                sessionIdentity: 'session',
                keeperGeneration: 'generation',
                revision: 1,
                members: const ['guest'],
              ),
            ),
            participant: _RemoteParticipant('keeper'),
            topic: AdmissionProtocol.topic,
          ),
        ),
      );
      publishGate.complete();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 2));
      check(room.participant!.published).length.equals(1);
      unawaited(transport.dispose());
      async.flushMicrotasks();
    });
  });

  test('transient reconnect does not emit terminal disconnect', () async {
    final room = _AdmissionRoom(null);
    final transport = _admissionTransport(room);
    final received = <AdmissionEvent>[];
    final subscription = transport.events.listen(received.add);
    addTearDown(() async {
      await subscription.cancel();
      await transport.dispose();
    });
    await room.listener.trigger(const RoomReconnectingEvent());
    await room.listener.trigger(const RoomResumingEvent());
    check(
      received.whereType<AdmissionConnectionInterrupted>(),
    ).length.equals(2);
    check(received.whereType<AdmissionRoomDisconnected>()).isEmpty();
    await room.listener.trigger(const RoomReconnectedEvent());
    check(received.last).isA<AdmissionConnectionRestored>();
    await room.listener.trigger(
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    check(received).length.equals(4);
    check(
      (received.last as AdmissionRoomDisconnected).reason,
    ).equals(SessionTransportDisconnectReason.reconnectAttemptsExceeded);
  });

  test('pending fails on terminal disconnect and ends on metadata', () async {
    final channel = _Channel('guest');
    channel.present.add('keeper');
    final guest = _pendingAdmissionController(
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
      const AdmissionRoomDisconnected(
        SessionTransportDisconnectReason.roomDeleted,
      ),
    );
    check(guest.status).equals(AdmissionStatus.failed);
    channel.controller.add(const AdmissionPresenceChanged('keeper', true));
    check(channel.sent).length.equals(sentBeforeFailure);
    await check(
      guest.requestAdmission(displayName: 'Guest'),
    ).throws<StateError>();
    channel.controller.add(const AdmissionRoomEnded());
    check(guest.status).equals(AdmissionStatus.ended);
  });

  test(
    'metadata end terminates pending admission and notifies listeners',
    () async {
      final channel = _Channel('guest');
      final guest = _pendingAdmissionController(
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
        const AdmissionRoomDisconnected(
          SessionTransportDisconnectReason.roomDeleted,
        ),
      );
      check(guest.status).equals(AdmissionStatus.ended);
      await check(
        guest.requestAdmission(displayName: 'Guest'),
      ).throws<StateError>();
    },
  );

  test(
    'ended metadata clears keeper queue and prevents future decisions',
    () async {
      final channel = _Channel('keeper');
      final keeper = _keeperAdmissionController(
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
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
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
      final endedKeeper = _keeperAdmissionController(
        channel: endedChannel,
        keeperIdentity: () => 'keeper',
        approvalRequired: false,
      );
      final endedGuestChannel = _Channel('guest')..hasEnded = true;
      final endedGuest = _pendingAdmissionController(
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
      await check(
        endedGuest.requestAdmission(displayName: 'Guest'),
      ).throws<StateError>();
    },
  );

  test(
    'pending admission reports absence, legacy Keeper timeout and no implicit decision',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        final channel = _Channel('guest', now: clock.now);
        final guest = _pendingAdmissionController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          now: clock.now,
          newId: () => 'r1',
        );
        unawaited(guest.requestAdmission(displayName: 'Guest'));
        async.flushMicrotasks();
        check(guest.status).equals(AdmissionStatus.pending);
        check(
          guest.keeperAvailability,
        ).equals(AdmissionKeeperAvailability.absent);

        channel.controller.add(const AdmissionPresenceChanged('keeper', true));
        check(
          guest.keeperAvailability,
        ).equals(AdmissionKeeperAvailability.checking);
        channel.present.add('keeper');
        async.elapse(const Duration(seconds: 10));
        check(guest.status).equals(AdmissionStatus.pending);
        check(
          guest.keeperAvailability,
        ).equals(AdmissionKeeperAvailability.unresponsive);
        check(channel.sent.whereType<AdmissionRequest>()).length.equals(1);
        channel.controller.add(const AdmissionConnectionRestored());
        check(
          guest.keeperAvailability,
        ).equals(AdmissionKeeperAvailability.checking);
        async.elapse(const Duration(seconds: 10));
        check(
          guest.keeperAvailability,
        ).equals(AdmissionKeeperAvailability.unresponsive);

        unawaited(guest.dispose());
        unawaited(channel.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('only a trusted late Keeper hello clears an availability warning', () {
    fakeAsync((async) {
      final clock = async.getClock(_fixedNow);
      final channel = _Channel('guest', now: clock.now)..present.add('keeper');
      final guest = _pendingAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        now: clock.now,
        newId: () => 'r1',
      );
      unawaited(guest.requestAdmission(displayName: 'Guest'));
      async.flushMicrotasks();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionHello(
            id: 'spoofed',
            senderIdentity: 'attacker',
            recipientIdentity: 'guest',
            expiresAt: _fixedNow,
          ),
        ),
      );
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.checking);

      async.elapse(const Duration(seconds: 10));
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.unresponsive);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionHello(
            id: 'late',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: _fixedNow,
          ),
        ),
      );
      check(guest.status).equals(AdmissionStatus.pending);
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.responsive);

      unawaited(guest.dispose());
      unawaited(channel.dispose());
      async.flushMicrotasks();
    });
  });

  test('a confirmed request remains responsive after a quick reconnect', () {
    fakeAsync((async) {
      final clock = async.getClock(_fixedNow);
      final channel = _Channel('guest', now: clock.now)..present.add('keeper');
      final guest = _pendingAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        now: clock.now,
      );
      unawaited(guest.requestAdmission(displayName: 'Guest'));
      async.flushMicrotasks();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionHello(
            id: 'early',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: _fixedNow,
          ),
        ),
      );
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.responsive);
      final sentBeforeReconnect = channel.sent.length;
      channel.controller.add(const AdmissionConnectionRestored());
      check(channel.sent).length.equals(sentBeforeReconnect + 1);
      check(channel.sent.last).equals(channel.sent.first);
      async.elapse(const Duration(seconds: 10));
      check(guest.status).equals(AdmissionStatus.pending);
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.responsive);

      channel.controller.add(const AdmissionPresenceChanged('keeper', false));
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.absent);
      channel.controller.add(const AdmissionPresenceChanged('keeper', true));
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.checking);
      async.elapse(const Duration(seconds: 10));
      check(
        guest.keeperAvailability,
      ).equals(AdmissionKeeperAvailability.unresponsive);

      unawaited(guest.dispose());
      unawaited(channel.dispose());
      async.flushMicrotasks();
    });
  });

  test(
    'reconnect after cancellation does not create an availability timer',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        final channel = _Channel('guest', now: clock.now)
          ..present.add('keeper');
        final guest = _pendingAdmissionController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          now: clock.now,
        );
        unawaited(guest.requestAdmission(displayName: 'Guest'));
        async.flushMicrotasks();
        unawaited(guest.cancel());
        async.flushMicrotasks();
        channel.controller.add(const AdmissionConnectionRestored());
        check(guest.status).equals(AdmissionStatus.cancelled);
        check(async.pendingTimers).isEmpty();

        unawaited(guest.dispose());
        unawaited(channel.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'availability timers stop when pending admission ends or is disposed',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        for (final finish
            in <void Function(PendingAdmissionController, _Channel)>[
              (guest, _) => unawaited(guest.cancel()),
              (_, channel) =>
                  channel.controller.add(const AdmissionRoomEnded()),
              (_, channel) => channel.controller.add(
                const AdmissionRoomDisconnected(
                  SessionTransportDisconnectReason.roomDeleted,
                ),
              ),
              (guest, _) => unawaited(guest.dispose()),
            ]) {
          final channel = _Channel('guest', now: clock.now)
            ..present.add('keeper');
          final guest = _pendingAdmissionController(
            channel: channel,
            keeperIdentity: () => 'keeper',
            now: clock.now,
          );
          unawaited(guest.requestAdmission(displayName: 'Guest'));
          async.flushMicrotasks();
          finish(guest, channel);
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 10));
          check(
            guest.keeperAvailability,
          ).equals(AdmissionKeeperAvailability.checking);
          unawaited(guest.dispose());
          unawaited(channel.dispose());
          async.flushMicrotasks();
        }
      });
    },
  );

  test(
    'keeper attach advertises to already waiting participant after lost request',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      guestChannel.peer = keeperChannel;
      keeperChannel.peer = guestChannel;
      guestChannel.present.add('keeper');
      keeperChannel.present.add('guest');
      final guest = _pendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final request = await guest.requestAdmission(displayName: 'Guest');
      // No keeper listener existed when the first request was delivered.
      final keeper = _keeperAdmissionController(
        channel: keeperChannel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await guest.dispose();
        await keeper.dispose();
        await guestChannel.dispose();
        await keeperChannel.dispose();
      });
      await pumpEventQueue();
      check(keeper.requests.single.id).equals(request.id);
      check(
        guestChannel.sent.whereType<AdmissionRequest>().map((sent) => sent.id),
      ).deepEquals([request.id, request.id, request.id]);
      check(keeperChannel.sent.whereType<AdmissionHello>()).length.equals(2);
      check(keeperChannel.sent.last.recipientIdentity).equals('guest');
      keeperChannel.controller.add(const AdmissionConnectionRestored());
      await Future<void>.value();
      check(keeperChannel.sent).length.equals(3);
      check(keeper.requests).length.equals(1);
    },
  );

  test('untrusted keeper hello cannot trigger resend', () async {
    final channel = _Channel('guest');
    channel.present.add('keeper');
    final guest = _pendingAdmissionController(
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
        expiresAt: _fixedNow,
      ),
      AdmissionHello(
        id: 'h2',
        senderIdentity: 'keeper',
        recipientIdentity: 'other',
        expiresAt: _fixedNow,
      ),
    ]) {
      channel.controller.add(AdmissionPacketReceived(hello));
    }
    check(channel.sent).length.equals(sent);
    check(guest.status).equals(AdmissionStatus.pending);
  });

  test(
    'presence resend recovers a dropped request, decision is targeted and deduped',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      guestChannel.peer = keeperChannel;
      keeperChannel.peer = guestChannel;
      guestChannel.present.add('keeper');
      final guest = _pendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final keeper = _keeperAdmissionController(
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
      check(keeper.requests.single.id).equals(request.id);
      check(
        guestChannel.sent.whereType<AdmissionRequest>().map((sent) => sent.id),
      ).deepEquals([request.id, request.id]);

      keeperChannel.dropNext = true;
      await keeper.approve(request.id, 'guest');
      check(guest.status).equals(AdmissionStatus.pending);
      check(keeper.requests).isEmpty();
      final approved = guest.changes.firstWhere(
        (status) => status == AdmissionStatus.approved,
      );
      guestChannel.controller.add(
        const AdmissionPresenceChanged('keeper', true),
      );
      await approved;
      check(guestChannel.sent).length.equals(4);
      check(keeperChannel.sent).length.equals(4);
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
    },
  );

  test(
    'approval before the waiting deadline permits a later joined receipt',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        final guestChannel = _Channel('guest', now: clock.now)
          ..present.add('keeper');
        final keeperChannel = _Channel('keeper', now: clock.now)
          ..present.add('guest');
        guestChannel.peer = keeperChannel;
        keeperChannel.peer = guestChannel;
        final guest = _pendingAdmissionController(
          channel: guestChannel,
          keeperIdentity: () => 'keeper',
          now: clock.now,
        );
        final keeper = _keeperAdmissionController(
          channel: keeperChannel,
          keeperIdentity: () => 'keeper',
          now: clock.now,
        );
        AdmissionRequest? request;
        unawaited(
          guest
              .requestAdmission(
                displayName: 'Guest',
                deadline: _fixedNow.add(const Duration(minutes: 20)),
              )
              .then((value) => request = value),
        );
        async.flushMicrotasks();
        check(keeper.requests.single.id).equals(request!.id);

        async.elapse(const Duration(minutes: 19, seconds: 59));
        unawaited(keeper.approve(request!.id, 'guest'));
        async.flushMicrotasks();
        check(guest.status).equals(AdmissionStatus.approved);
        check(
          keeper.attempts.single.joinDeadline,
        ).equals(clock.now().add(AdmissionProtocol.lifetime));

        async.elapse(const Duration(seconds: 2));
        check(guest.status).equals(AdmissionStatus.approved);
        final receipt = AdmissionProtocol.joined(request!);
        check(
          AdmissionProtocol.decode(
            AdmissionProtocol.encode(receipt),
            senderIdentity: 'guest',
            now: clock.now(),
          ),
        ).isA<AdmissionJoined>();
        unawaited(guestChannel.send(receipt));
        async.flushMicrotasks();
        check(
          keeper.attempts.single.status,
        ).equals(KeeperAdmissionStatus.joined);
        check(keeper.roster).deepEquals(['guest']);

        unawaited(guest.dispose());
        unawaited(keeper.dispose());
        unawaited(guestChannel.dispose());
        unawaited(keeperChannel.dispose());
        async.flushMicrotasks();
      });
    },
  );

  for (final offset in [Duration.zero, const Duration(seconds: 1)]) {
    test(
      'approval at waiting deadline + $offset expires without timer firing',
      () {
        fakeAsync((async) {
          var now = _fixedNow;
          final guestChannel = _Channel('guest', now: () => now)
            ..present.add('keeper');
          final keeperChannel = _Channel('keeper', now: () => now)
            ..present.add('guest');
          guestChannel.peer = keeperChannel;
          keeperChannel.peer = guestChannel;
          final guest = _pendingAdmissionController(
            channel: guestChannel,
            keeperIdentity: () => 'keeper',
            now: () => now,
          );
          final keeper = _keeperAdmissionController(
            channel: keeperChannel,
            keeperIdentity: () => 'keeper',
            now: () => now,
          );
          AdmissionRequest? request;
          final deadline = _fixedNow.add(const Duration(minutes: 20));
          unawaited(
            guest
                .requestAdmission(displayName: 'Guest', deadline: deadline)
                .then((value) => request = value),
          );
          async.flushMicrotasks();
          check(keeper.requests.single.id).equals(request!.id);
          now = deadline.add(offset);
          check(guest.status).equals(AdmissionStatus.pending);
          unawaited(keeper.approve(request!.id, 'guest'));
          async.flushMicrotasks();
          check(
            keeperChannel.sent.whereType<AdmissionDecision>().single.approved,
          ).isTrue();
          check(guest.status).equals(AdmissionStatus.expired);
          check(keeper.roster).isEmpty();

          unawaited(guest.dispose());
          unawaited(keeper.dispose());
          unawaited(guestChannel.dispose());
          unawaited(keeperChannel.dispose());
          async.flushMicrotasks();
        });
      },
    );
  }

  test(
    'an unanswered first approval is retried once without another participant action',
    () {
      fakeAsync((async) {
        final clock = async.getClock(_fixedNow);
        final guestChannel = _Channel('guest', now: clock.now);
        final keeperChannel = _Channel('keeper', now: clock.now);
        guestChannel.peer = keeperChannel;
        keeperChannel.peer = guestChannel;
        guestChannel.present.add('keeper');
        keeperChannel.present.add('guest');
        final guest = _pendingAdmissionController(
          channel: guestChannel,
          keeperIdentity: () => 'keeper',
          now: clock.now,
        );
        final keeper = _keeperAdmissionController(
          channel: keeperChannel,
          keeperIdentity: () => 'keeper',
          now: clock.now,
        );
        AdmissionRequest? request;
        unawaited(
          guest
              .requestAdmission(displayName: 'Guest')
              .then((value) => request = value),
        );
        async.flushMicrotasks();
        check(keeper.requests).length.equals(1);
        keeperChannel.dropNext = true;
        unawaited(keeper.approve(request!.id, 'guest'));
        async.flushMicrotasks();
        check(guest.status).equals(AdmissionStatus.pending);
        check(
          keeper.attempts.single.status,
        ).equals(KeeperAdmissionStatus.joining);

        async
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();
        check(guest.status).equals(AdmissionStatus.approved);
        check(
          keeperChannel.sent.whereType<AdmissionDecision>(),
        ).length.equals(2);
        async.elapse(const Duration(seconds: 4));
        check(
          keeperChannel.sent.whereType<AdmissionDecision>(),
        ).length.equals(2);
        unawaited(guest.dispose());
        unawaited(keeper.dispose());
        unawaited(guestChannel.dispose());
        unawaited(keeperChannel.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'keeper rejects non-keeper authority and expired or changed requests',
    () async {
      final channel = _Channel('keeper');
      var keeperIdentity = 'other';
      var now = DateTime.utc(2026);
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => keeperIdentity,
        approvalRequired: false,
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
      check(channel.sent.whereType<AdmissionDecision>()).isEmpty();
      keeperIdentity = 'keeper';
      keeper.setApprovalRequired(true);
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
    'request stays pending beyond two minutes and reaches a late Keeper',
    () async {
      final channel = _Channel('guest');
      var now = _fixedNow;
      final guest = _pendingAdmissionController(
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
      // The SDK emits presence before adding the Keeper to remoteParticipants.
      channel.controller.add(const AdmissionPresenceChanged('keeper', true));
      check(channel.sent).length.equals(1);
      channel.present.add('keeper');
      now = now.add(const Duration(minutes: 3));
      channel.controller.add(const AdmissionConnectionRestored());
      check(guest.status).equals(AdmissionStatus.pending);
      check(channel.sent).length.equals(2);
      final request = guest.request!;
      channel.controller.add(
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
      check(guest.status).equals(AdmissionStatus.approved);
    },
  );

  for (final cancelWhileAway in [false, true]) {
    test(
      'Keeper reconnect restores ${cancelWhileAway ? 'cancellation' : 'the waiting request'} before presence catches up',
      () async {
        final guestChannel = _Channel('guest')..present.add('keeper');
        final firstChannel = _Channel('keeper')..present.add('guest');
        guestChannel.peer = firstChannel;
        firstChannel.peer = guestChannel;
        final guest = _pendingAdmissionController(
          channel: guestChannel,
          keeperIdentity: () => 'keeper',
          newId: () => 'waiting-request',
        );
        final firstKeeper = _keeperAdmissionController(
          channel: firstChannel,
          keeperIdentity: () => 'keeper',
        );
        addTearDown(() async {
          await guest.dispose();
          await guestChannel.dispose();
          await firstKeeper.dispose();
          await firstChannel.dispose();
        });
        final request = await guest.requestAdmission(displayName: 'Guest');
        await pumpEventQueue();
        check(firstKeeper.requests.single.id).equals(request.id);
        await firstKeeper.dispose();
        await firstChannel.dispose();
        guestChannel
          ..peer = null
          ..present.remove('keeper')
          ..controller.add(const AdmissionPresenceChanged('keeper', false));
        check(guest.status).equals(AdmissionStatus.pending);
        check(guest.request).identicalTo(request);
        if (cancelWhileAway) await guest.cancel();

        final returningChannel = _Channel('keeper')
          ..present.add('guest')
          ..peer = guestChannel;
        guestChannel.peer = returningChannel;
        final returningKeeper = _keeperAdmissionController(
          channel: returningChannel,
          keeperIdentity: () => 'keeper',
        );
        addTearDown(() async {
          await returningKeeper.dispose();
          await returningChannel.dispose();
        });
        await pumpEventQueue();
        check(guestChannel.isPresent('keeper')).isFalse();
        if (cancelWhileAway) {
          check(guest.status).equals(AdmissionStatus.cancelled);
          check(guestChannel.sent.last).isA<AdmissionCancel>();
          check(returningKeeper.requests).isEmpty();
        } else {
          check(guest.status).equals(AdmissionStatus.pending);
          check(returningKeeper.requests.single.id).equals(request.id);
          await returningKeeper.approve(request.id, 'guest');
          await pumpEventQueue();
          check(guest.status).equals(AdmissionStatus.approved);
        }
      },
    );
  }

  for (final applicantAhead in [true, false]) {
    test(
      'admission and roster synchronize when ${applicantAhead ? 'applicant' : 'Keeper'} clock is ahead',
      () async {
        final base = DateTime.utc(2026);
        final applicantNow = base.add(
          Duration(seconds: applicantAhead ? 30 : 0),
        );
        final keeperNow = base.add(Duration(seconds: applicantAhead ? 0 : 30));
        final guestChannel = _Channel('guest', now: () => applicantNow)
          ..present.add('keeper');
        final keeperChannel = _Channel('keeper', now: () => keeperNow)
          ..present.add('guest');
        guestChannel.peer = keeperChannel;
        keeperChannel.peer = guestChannel;
        final guest = _pendingAdmissionController(
          channel: guestChannel,
          keeperIdentity: () => 'keeper',
          now: () => applicantNow,
        );
        final keeper = _keeperAdmissionController(
          channel: keeperChannel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
          now: () => keeperNow,
        );
        addTearDown(() async {
          await guest.dispose();
          await keeper.dispose();
          await guestChannel.dispose();
          await keeperChannel.dispose();
        });
        final request = await guest.requestAdmission(displayName: 'Guest');
        await pumpEventQueue();
        check(keeper.requests.single.id).equals(request.id);
        await keeper.approve(request.id, 'guest');
        await pumpEventQueue();
        check(guest.status).equals(AdmissionStatus.approved);

        final roster = _clientAdmissionRosterController(
          channel: guestChannel,
          keeperIdentity: () => 'keeper',
          sessionIdentity: 'session',
          now: () => applicantNow,
        );
        addTearDown(roster.dispose);
        await pumpEventQueue();
        check(roster.hasAuthoritativeRoster).isTrue();
        check(roster.roster!.members).isEmpty();
        await guestChannel.send(AdmissionProtocol.joined(request));
        await pumpEventQueue();
        check(
          keeper.attempts.single.status,
        ).equals(KeeperAdmissionStatus.joined);
        check(roster.roster!.members).deepEquals(['guest']);
      },
    );
  }

  test(
    'failed initial send stays pending and resends on keeper presence',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      guestChannel.peer = keeperChannel;
      guestChannel.present.add('keeper');
      final guest = _pendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final keeper = _keeperAdmissionController(
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

  test('cancel completes locally while its send remains unresolved', () async {
    final channel = _Channel('guest')..present.add('keeper');
    final guest = _pendingAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
    );
    addTearDown(() async {
      await guest.dispose();
      await channel.dispose();
    });
    await guest.requestAdmission(displayName: 'Guest');
    final sendGate = Completer<void>();
    channel.beforeSend = (packet) =>
        packet is AdmissionCancel ? sendGate.future : Future<void>.value();
    var completed = false;
    final cancellation = guest.cancel().then((_) => completed = true);
    check(guest.status).equals(AdmissionStatus.cancelled);
    await pumpEventQueue();
    check(completed).isTrue();
    check(channel.sent.last).isA<AdmissionCancel>();
    sendGate.completeError(StateError('send failed'));
    await cancellation;
    await pumpEventQueue();
  });

  test(
    'cancel is targeted, terminal locally, and prevents request replay',
    () async {
      final guestChannel = _Channel('guest');
      final keeperChannel = _Channel('keeper');
      guestChannel.peer = keeperChannel;
      guestChannel.present.add('keeper');
      final guest = _pendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final keeper = _keeperAdmissionController(
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
        const AdmissionRoomDisconnected(
          SessionTransportDisconnectReason.clientInitiated,
        ),
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
      final guest = _pendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        newId: () => 'r1',
      );
      final keeper = _keeperAdmissionController(
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
    'admitted identity rejoins automatically after participant reload',
    () async {
      var now = _fixedNow;
      final guestChannel = _Channel('guest', now: () => now);
      final keeperChannel = _Channel('keeper', now: () => now);
      guestChannel.peer = keeperChannel;
      keeperChannel.peer = guestChannel;
      guestChannel.present.add('keeper');
      keeperChannel.present.add('guest');
      var nextId = 0;
      PendingAdmissionController guest() => _pendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        now: () => now,
        newId: () => 'r${++nextId}',
      );
      var participant = guest();
      final keeper = _keeperAdmissionController(
        channel: keeperChannel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        now: () => now,
      );
      addTearDown(() async {
        await participant.dispose();
        await keeper.dispose();
        await guestChannel.dispose();
        await keeperChannel.dispose();
      });

      keeper.setApprovalRequired(false);
      final first = await participant.requestAdmission(displayName: 'Guest');
      await pumpEventQueue();
      check(participant.status).equals(AdmissionStatus.approved);
      check(participant.isReturningParticipant).isFalse();
      check(
        keeperChannel.sent
            .whereType<AdmissionDecision>()
            .last
            .isReturningParticipant,
      ).isFalse();
      await guestChannel.send(AdmissionProtocol.joined(first));
      check(keeper.roster).deepEquals(['guest']);
      keeperChannel.present.remove('guest');
      keeperChannel.controller.add(
        const AdmissionPresenceChanged('guest', false),
      );
      check(keeper.roster).deepEquals(['guest']);

      keeper.setApprovalRequired(true);
      await participant.dispose();
      now = now.add(const Duration(milliseconds: 1));
      keeperChannel.present.add('guest');
      participant = guest();
      final second = await participant.requestAdmission(displayName: 'Guest');
      await pumpEventQueue();
      check(participant.status).equals(AdmissionStatus.approved);
      check(participant.isReturningParticipant).isTrue();
      check(
        keeperChannel.sent
            .whereType<AdmissionDecision>()
            .last
            .isReturningParticipant,
      ).isTrue();
      check(keeper.requests).isEmpty();
      check(keeper.roster).isEmpty();
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);

      await guestChannel.send(AdmissionProtocol.joined(second));
      check(keeper.roster).deepEquals(['guest']);
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
    },
  );

  test('revocation removes admission and requires a fresh decision', () async {
    final channel = _Channel('keeper')..present.addAll(['guest', 'friend']);
    final store = KeeperAdmissionRosterStore()
      ..replace(['guest', 'friend'], 4, awaitingReadiness: ['guest']);
    final keeper = _keeperAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      sessionIdentity: 'session',
      rosterStore: store,
    );
    var changes = 0;
    final subscription = keeper.changes.listen((_) => changes++);
    addTearDown(() async {
      await subscription.cancel();
      await keeper.dispose();
      await channel.dispose();
    });
    final old = AdmissionRequest(
      id: 'old',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: _fixedNow.add(const Duration(minutes: 1)),
      displayName: 'Guest',
    );
    channel.controller.add(AdmissionPacketReceived(old));
    await pumpEventQueue();
    changes = 0;
    keeper.revoke('guest');
    await pumpEventQueue();
    check(changes > 0).isTrue();
    check(keeper.roster).deepEquals(['friend']);
    check(store.members.toList()).deepEquals(['friend']);
    check(store.awaitingReadiness).isEmpty();
    check(store.revision).equals(5);
    final update = channel.sent.whereType<AdmissionRosterUpdated>().last;
    check(update.recipientIdentity).equals('friend');
    check(update.revision).equals(5);
    check(update.members).deepEquals(['friend']);
    channel.controller.add(
      AdmissionPacketReceived(AdmissionProtocol.joined(old)),
    );
    channel.controller.add(AdmissionPacketReceived(old));
    check(keeper.roster).deepEquals(['friend']);
    check(keeper.requests).isEmpty();
    check(keeper.attempts).isEmpty();

    final fresh = AdmissionRequest(
      id: 'fresh',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: old.expiresAt.add(const Duration(milliseconds: 1)),
      displayName: 'Guest',
    );
    channel.controller.add(AdmissionPacketReceived(fresh));
    check(keeper.requests.single.id).equals('fresh');
    await keeper.approve('fresh', 'guest');
    check(store.revoked.contains('guest')).isFalse();
    check(store.revision).equals(6);
    channel.controller.add(
      AdmissionPacketReceived(AdmissionProtocol.joined(fresh)),
    );
    check(keeper.roster).deepEquals(['friend', 'guest']);
  });

  test('unban reservation rejects an approval already in flight', () async {
    final channel = _Channel('keeper');
    final keeper = _keeperAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      sessionIdentity: 'reservation-in-flight',
    );
    final gate = Completer<void>();
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      await keeper.dispose();
      await channel.dispose();
    });
    channel.beforeSend = (packet) =>
        packet is AdmissionDecision ? gate.future : Future.value();
    final request = AdmissionRequest(
      id: 'pending',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: _fixedNow.add(const Duration(minutes: 1)),
      displayName: 'Guest',
    );
    channel.controller.add(AdmissionPacketReceived(request));
    final approval = keeper.approve(request.id, 'guest');
    check(
      () => AdmissionApprovalGuard.reserve('reservation-in-flight', 'guest'),
    ).throws<StateError>();
    gate.complete();
    await approval;
    AdmissionApprovalGuard.reserve('reservation-in-flight', 'guest');
    AdmissionApprovalGuard.release('reservation-in-flight', 'guest');
  });

  test(
    'revocation isolates overlapping approvals and requires explicit readmission',
    () async {
      final channel = _Channel('keeper');
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final old = AdmissionRequest(
        id: 'old',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      final fresh = AdmissionRequest(
        id: 'fresh',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: old.expiresAt.add(const Duration(milliseconds: 1)),
        displayName: 'Guest',
      );
      final oldGate = Completer<void>();
      final freshGate = Completer<void>();
      channel.beforeSend = (packet) {
        if (packet is AdmissionDecision) {
          return packet.id == 'old' ? oldGate.future : freshGate.future;
        }
        return Future.value();
      };
      channel.controller.add(AdmissionPacketReceived(old));
      final oldApproval = keeper.approve('old', 'guest');
      keeper
        ..revoke('guest')
        ..setApprovalRequired(false);
      channel.controller.add(AdmissionPacketReceived(fresh));
      await pumpEventQueue();
      check(keeper.approvalRequired).isFalse();
      check(keeper.requests.single.id).equals('fresh');
      check(
        channel.sent.whereType<AdmissionDecision>().where(
          (d) => d.id == 'fresh',
        ),
      ).isEmpty();
      oldGate.complete();
      await check(oldApproval).throws<StateError>();
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(old)),
      );
      check(keeper.roster).isEmpty();
      final freshApproval = keeper.approve('fresh', 'guest');
      freshGate.complete();
      await freshApproval;
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(fresh)),
      );
      check(keeper.roster).deepEquals(['guest']);
      check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.joined);
    },
  );

  test(
    'a historical roster participant rejoins automatically while others wait',
    () async {
      var now = _fixedNow;
      final channel = _Channel('keeper', now: () => now)
        ..present.addAll(['guest', 'friend']);
      final store = KeeperAdmissionRosterStore()
        ..replace(const ['guest', 'friend'], 1);
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
        now: () => now,
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      AdmissionRequest request(String id, String sender) => AdmissionRequest(
        id: id,
        senderIdentity: sender,
        recipientIdentity: 'keeper',
        expiresAt: now.add(AdmissionProtocol.requestLifetime),
        displayName: sender,
      );
      final returning = request('return', 'guest');
      check(keeper.approvalRequired).isTrue();
      channel.controller.add(AdmissionPacketReceived(returning));
      await pumpEventQueue();
      check(keeper.roster).deepEquals(['friend']);
      check(keeper.requests).isEmpty();
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      check(channel.sent.whereType<AdmissionDecision>().last.approved).isTrue();
      check(
        channel.sent
            .whereType<AdmissionRosterUpdated>()
            .lastWhere((packet) => packet.recipientIdentity == 'friend')
            .members,
      ).deepEquals(['friend']);

      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(returning)),
      );
      check(keeper.roster).deepEquals(['friend', 'guest']);

      final newcomer = request('newcomer', 'newcomer');
      channel.controller.add(AdmissionPacketReceived(newcomer));
      check(keeper.requests.single.id).equals(newcomer.id);
      check(keeper.roster).deepEquals(['friend', 'guest']);

      keeper.setDeclinedIdentities({'guest'});
      now = now.add(const Duration(milliseconds: 1));
      final blockedReturn = request('blocked-return', 'guest');
      channel.controller.add(AdmissionPacketReceived(blockedReturn));
      await pumpEventQueue();
      check(keeper.requests.single.id).equals(newcomer.id);
      final decision = channel.sent.whereType<AdmissionDecision>().last;
      check(decision.id).equals(blockedReturn.id);
      check(decision.approved).isFalse();
      check(decision.isReturningParticipant).isFalse();
    },
  );

  test(
    'failed automatic return approval exposes the request for manual approval',
    () async {
      final channel = _Channel('keeper');
      final store = KeeperAdmissionRosterStore()..replace(const ['guest'], 1);
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final sendStarted = Completer<void>();
      final failSend = Completer<void>();
      channel.beforeSend = (packet) async {
        if (packet is AdmissionDecision) {
          sendStarted.complete();
          await failSend.future;
        }
      };
      final request = AdmissionRequest(
        id: 'return',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: _fixedNow.add(AdmissionProtocol.requestLifetime),
        displayName: 'Guest',
      );

      channel.controller.add(AdmissionPacketReceived(request));
      await sendStarted.future;
      check(keeper.requests).isEmpty();

      failSend.completeError(StateError('offline'));
      await pumpEventQueue();
      check(keeper.requests.single.id).equals(request.id);

      channel.beforeSend = null;
      await keeper.approve(request.id, request.senderIdentity);
      check(keeper.requests).isEmpty();
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      check(channel.sent.whereType<AdmissionDecision>().last.approved).isTrue();
    },
  );

  test(
    'disconnect removes queue; resend restores it, not a superseded ID',
    () async {
      final channel = _Channel('keeper');
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final expiration = DateTime.fromMillisecondsSinceEpoch(
        _fixedNow.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
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
      final fixedNow = _fixedNow;
      var nextId = 0;
      final guest = _pendingAdmissionController(
        channel: guestChannel,
        keeperIdentity: () => 'keeper',
        now: () => fixedNow,
        newId: () => 'r${++nextId}',
      );
      final keeper = _keeperAdmissionController(
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
      final keeper = _keeperAdmissionController(
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
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
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
      check(channel.sent).length.equals(4);
      check((channel.sent.last as AdmissionDecision).approved).isFalse();
    },
  );

  test(
    'older in-flight decision cannot remove or answer newer request',
    () async {
      final channel = _Channel('keeper');
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final expiration = _fixedNow.add(const Duration(minutes: 1));
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
                .add(const Duration(hours: 25))
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
      final keeper = _keeperAdmissionController(
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
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      final receipt = AdmissionProtocol.joined(request);
      channel.controller.add(AdmissionPacketReceived(receipt));
      check(keeper.attempts).isEmpty();
      channel.controller.add(AdmissionPacketReceived(request));
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.requested);
      channel.controller.add(AdmissionPacketReceived(receipt));
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.requested);
      await keeper.approve(request.id, 'guest');
      check(keeper.requests).isEmpty();
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      check(keeper.attempts.single.joinDeadline).equals(request.expiresAt);
      channel.controller.add(AdmissionPacketReceived(request));
      await Future<void>.value();
      check(channel.sent).length.equals(3);
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
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
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
      final keeper = _keeperAdmissionController(
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
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
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
      final keeper = _keeperAdmissionController(
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
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
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
      final keeper = _keeperAdmissionController(
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
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
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

  test(
    'long-lived requests still time out after approval without a receipt',
    () {
      fakeAsync((async) {
        final now = async.getClock(DateTime.utc(2026));
        final channel = _Channel('keeper');
        final keeper = _keeperAdmissionController(
          channel: channel,
          keeperIdentity: () => 'keeper',
          now: now.now,
        );
        final request = AdmissionRequest(
          id: 'long-request',
          senderIdentity: 'guest',
          recipientIdentity: 'keeper',
          expiresAt: now.now().add(AdmissionProtocol.requestLifetime),
          displayName: 'Guest',
        );
        channel.controller.add(AdmissionPacketReceived(request));
        async.elapse(const Duration(minutes: 3));
        check(keeper.requests.single.id).equals(request.id);
        unawaited(keeper.approve(request.id, 'guest'));
        async.flushMicrotasks();
        check(
          keeper.attempts.single.status,
        ).equals(KeeperAdmissionStatus.joining);
        async.elapse(AdmissionProtocol.lifetime);
        check(
          keeper.attempts.single.status,
        ).equals(KeeperAdmissionStatus.timedOut);
        channel.controller.add(
          AdmissionPacketReceived(AdmissionProtocol.joined(request)),
        );
        check(
          keeper.attempts.single.status,
        ).equals(KeeperAdmissionStatus.timedOut);
        unawaited(keeper.dispose());
        unawaited(channel.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('failed join, superseded receipt, cancel and end stay safe', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026);
      final clock = async.getClock(start);
      final channel = _Channel('keeper');
      final keeper = _keeperAdmissionController(
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
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joinFailed);
      check(keeper.roster).isEmpty();
      final second = request('second', start.add(const Duration(seconds: 31)));
      channel.controller.add(AdmissionPacketReceived(second));
      unawaited(keeper.approve(second.id, 'guest'));
      async.flushMicrotasks();
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
      channel.controller.add(
        AdmissionPacketReceived(AdmissionProtocol.joined(first)),
      );
      check(keeper.attempts.single.request.id).equals(second.id);
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.joining);
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
      check(
        keeper.attempts.single.status,
      ).equals(KeeperAdmissionStatus.cancelled);
      channel.controller.add(AdmissionPacketReceived(third));
      check(keeper.requests).isEmpty();
      channel.controller.add(const AdmissionRoomEnded());
      check(keeper.attempts).isEmpty();
      unawaited(keeper.dispose());
      unawaited(channel.dispose());
      async.flushMicrotasks();
    });
  });

  test('roster packets bind session, generation, revision, and members', () {
    final now = DateTime.utc(2026);
    final snapshot = AdmissionRosterSnapshot(
      id: 'snapshot',
      senderIdentity: 'keeper',
      recipientIdentity: 'guest',
      expiresAt: now.add(const Duration(minutes: 1)),
      sessionIdentity: 'session',
      keeperGeneration: 'generation',
      revision: 2,
      members: const ['guest'],
    );
    final bytes = AdmissionProtocol.encode(snapshot);
    check(
      AdmissionProtocol.decode(bytes, senderIdentity: 'keeper', now: now),
    ).isA<AdmissionRosterSnapshot>();
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    for (final invalid in [
      {...payload, 'session': ''},
      {...payload, 'generation': ''},
      {...payload, 'revision': -1},
      {
        ...payload,
        'members': ['guest', 'guest'],
      },
    ]) {
      check(
        AdmissionProtocol.decode(
          utf8.encode(jsonEncode(invalid)),
          senderIdentity: 'keeper',
          now: now,
        ),
      ).isNull();
    }
  });

  test(
    'pending participant ignores decisions from the wrong keeper or request',
    () async {
      final channel = _Channel('guest');
      channel.present.add('keeper');
      final guest = _pendingAdmissionController(
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

  test('keeper publishes roster update after a joined receipt', () async {
    final channel = _Channel('keeper')..present.add('guest');
    final keeper = _keeperAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      sessionIdentity: 'session',
      keeperGeneration: 'generation',
      newId: () => 'packet',
    );
    addTearDown(() async {
      await keeper.dispose();
      await channel.dispose();
    });
    final request = AdmissionRequest(
      id: 'request',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: _fixedNow.add(const Duration(minutes: 1)),
      displayName: 'Guest',
    );
    channel.controller.add(AdmissionPacketReceived(request));
    await keeper.approve(request.id, request.senderIdentity);
    channel.controller.add(
      AdmissionPacketReceived(AdmissionProtocol.joined(request)),
    );

    check(keeper.roster).deepEquals(['guest']);
    check(keeper.rosterRevision).equals(1);
    final update = channel.sent.whereType<AdmissionRosterUpdated>().single;
    check(update.keeperGeneration).equals('generation');
    check(update.revision).equals(1);
    check(update.members).deepEquals(['guest']);
  });

  test('keeper sends roster only to admitted participants', () async {
    final channel = _Channel('keeper')..present.addAll(['member', 'applicant']);
    final store = KeeperAdmissionRosterStore(keeperGeneration: 'generation')
      ..replace(const ['member'], 1);
    final keeper = _keeperAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      sessionIdentity: 'session',
      rosterStore: store,
    );
    addTearDown(() async {
      await keeper.dispose();
      await channel.dispose();
    });

    check(
      channel.sent
          .whereType<AdmissionRosterSnapshot>()
          .single
          .recipientIdentity,
    ).equals('member');
    channel.controller.add(
      AdmissionPacketReceived(
        AdmissionRosterRequest(
          id: 'applicant-request',
          senderIdentity: 'applicant',
          recipientIdentity: 'keeper',
          expiresAt: _fixedNow.add(const Duration(minutes: 1)),
          sessionIdentity: 'session',
        ),
      ),
    );
    final applicantSnapshot = channel.sent
        .whereType<AdmissionRosterSnapshot>()
        .last;
    check(applicantSnapshot.recipientIdentity).equals('applicant');
    check(applicantSnapshot.requestId).equals('applicant-request');
    check(applicantSnapshot.members).isEmpty();
    check(channel.sent.whereType<AdmissionRosterSnapshot>()).length.equals(2);

    final request = AdmissionRequest(
      id: 'join-request',
      senderIdentity: 'applicant',
      recipientIdentity: 'keeper',
      expiresAt: _fixedNow.add(const Duration(minutes: 1)),
      displayName: 'Applicant',
    );
    channel.controller.add(AdmissionPacketReceived(request));
    await keeper.approve(request.id, request.senderIdentity);
    check(channel.sent.whereType<AdmissionRosterUpdated>()).isEmpty();
    channel.controller.add(
      AdmissionPacketReceived(AdmissionProtocol.joined(request)),
    );
    check(
      channel.sent
          .whereType<AdmissionRosterUpdated>()
          .map((packet) => packet.recipientIdentity)
          .toSet(),
    ).deepEquals({'member', 'applicant'});
  });

  test(
    'client ignores delayed roster generations and duplicate updates',
    () async {
      final channel = _Channel('guest')..present.add('keeper');
      var nextId = 0;
      final client = _clientAdmissionRosterController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        newId: () => 'request-${++nextId}',
      );
      addTearDown(() async {
        await client.dispose();
        await channel.dispose();
      });
      final expiry = _fixedNow.add(const Duration(minutes: 1));
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'snapshot-1',
            requestId: 'request-1',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-1',
            revision: 8,
            members: const ['guest'],
          ),
        ),
      );
      check(client.contains('guest')).isTrue();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'duplicate',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-1',
            revision: 8,
            members: const ['guest'],
          ),
        ),
      );
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(1);

      final changes = <AdmissionRoster?>[];
      final subscription = client.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'gap',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-1',
            revision: 11,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(client.roster!.revision).equals(11);
      check(client.contains('guest')).isTrue();
      check(client.contains('other')).isTrue();
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(1);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'duplicate-gap',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-1',
            revision: 11,
            members: const ['guest'],
          ),
        ),
      );
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'delayed',
            requestId: 'request-1',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-0',
            revision: 99,
            members: const ['stale'],
          ),
        ),
      );
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'stale-revision-10',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-1',
            revision: 10,
            members: const ['guest'],
          ),
        ),
      );
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(1);
      check(client.roster!.revision).equals(11);
      check(client.roster!.members).deepEquals(['guest', 'other']);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'removal-revision-12',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-1',
            revision: 12,
            members: const ['guest'],
          ),
        ),
      );
      check(client.roster!.revision).equals(12);
      check(client.roster!.members).deepEquals(['guest']);
      await pumpEventQueue();
      check(changes.where((roster) => roster == null)).isEmpty();

      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'new-generation',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-2',
            revision: 4,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(2);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'snapshot-2',
            requestId: channel.sent.whereType<AdmissionRosterRequest>().last.id,
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-2',
            revision: 4,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(client.roster?.keeperGeneration).equals('generation-2');
      check(client.contains('other')).isTrue();
      await pumpEventQueue();

      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'keeper-restarted',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-3',
            revision: 0,
            members: const ['guest'],
          ),
        ),
      );
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(3);
      check(client.roster).isNull();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'snapshot-3',
            requestId: channel.sent.whereType<AdmissionRosterRequest>().last.id,
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation-3',
            revision: 0,
            members: const ['guest'],
          ),
        ),
      );
      check(client.roster?.keeperGeneration).equals('generation-3');
      check(client.contains('other')).isFalse();
    },
  );

  test(
    'roster updates validate packets and beat an older pending snapshot',
    () async {
      final channel = _Channel('guest')..present.add('keeper');
      var nextId = 0;
      final client = _clientAdmissionRosterController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        newId: () => 'request-${++nextId}',
      );
      addTearDown(() async {
        await client.dispose();
        await channel.dispose();
      });
      final expiry = _fixedNow.add(const Duration(minutes: 1));
      void snapshot(int revision, List<String> members, String requestId) {
        channel.controller.add(
          AdmissionPacketReceived(
            AdmissionRosterSnapshot(
              id: 'snapshot-$revision',
              requestId: requestId,
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: expiry,
              sessionIdentity: 'session',
              keeperGeneration: 'generation',
              revision: revision,
              members: members,
            ),
          ),
        );
      }

      void update({
        int revision = 11,
        String sender = 'keeper',
        String recipient = 'guest',
        String session = 'session',
        String generation = 'generation',
        List<String> members = const ['guest', 'new'],
        DateTime? expiresAt,
      }) {
        channel.controller.add(
          AdmissionPacketReceived(
            AdmissionRosterUpdated(
              id: 'update',
              senderIdentity: sender,
              recipientIdentity: recipient,
              expiresAt: expiresAt ?? expiry,
              sessionIdentity: session,
              keeperGeneration: generation,
              revision: revision,
              members: members,
            ),
          ),
        );
      }

      snapshot(8, ['guest', 'old'], 'request-1');
      update(sender: 'mallory');
      update(recipient: 'someone-else');
      update(session: 'other-session');
      update(generation: '');
      update(revision: -1);
      update(members: ['new', 'new']);
      update(members: ['']);
      update(expiresAt: _fixedNow);
      check(client.roster!.revision).equals(8);
      check(client.roster!.members).deepEquals(['guest', 'old']);
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(1);
      await pumpEventQueue();

      channel.controller.add(const AdmissionPresenceChanged('keeper', true));
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(2);
      await pumpEventQueue();
      update();
      check(client.roster!.revision).equals(11);
      check(client.roster!.members).deepEquals(['guest', 'new']);
      update(revision: 9, members: ['stale']);
      update(revision: 11, members: ['duplicate']);
      snapshot(9, [
        'stale-snapshot',
      ], channel.sent.whereType<AdmissionRosterRequest>().last.id);
      check(client.roster!.revision).equals(11);
      check(client.roster!.members).deepEquals(['guest', 'new']);
      check(client.isSynchronizing).isTrue();
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(3);
      snapshot(11, [
        'guest',
        'new',
      ], channel.sent.whereType<AdmissionRosterRequest>().last.id);
      check(client.isSynchronizing).isFalse();
      update(revision: 12, members: ['new']);
      check(client.roster).isNull();
      check(client.contains('new')).isFalse();
    },
  );

  test(
    'non-admitted client cannot gain members from an unsolicited update',
    () async {
      final channel = _Channel('guest')..present.add('keeper');
      var nextId = 0;
      final client = _clientAdmissionRosterController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        newId: () => 'request-${++nextId}',
      );
      addTearDown(() async {
        await client.dispose();
        await channel.dispose();
      });
      final expiry = _fixedNow.add(const Duration(minutes: 1));
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'empty',
            requestId: 'request-1',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 8,
            members: const [],
          ),
        ),
      );
      check(client.roster!.members).isEmpty();
      await pumpEventQueue();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'unsolicited',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 11,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(client.roster!.revision).equals(8);
      check(client.roster!.members).isEmpty();
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(2);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'admitted',
            requestId: 'request-2',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 11,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(client.roster!.members).deepEquals(['guest', 'other']);
    },
  );

  test(
    'new keeper with the same generation requires a correlated snapshot',
    () async {
      final channel = _Channel('guest')
        ..present.addAll(['keeper', 'new-keeper']);
      var keeper = 'keeper';
      var nextId = 0;
      final client = _clientAdmissionRosterController(
        channel: channel,
        keeperIdentity: () => keeper,
        sessionIdentity: 'session',
        newId: () => 'request-${++nextId}',
      );
      addTearDown(() async {
        await client.dispose();
        await channel.dispose();
      });
      final expiry = _fixedNow.add(const Duration(minutes: 1));
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'initial',
            requestId: 'request-1',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 8,
            members: const ['guest'],
          ),
        ),
      );
      check(client.contains('guest')).isTrue();
      keeper = 'new-keeper';
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterUpdated(
            id: 'new-keeper-update',
            senderIdentity: 'new-keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 11,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(client.roster).isNull();
      check(
        channel.sent.whereType<AdmissionRosterRequest>().last.recipientIdentity,
      ).equals('new-keeper');
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(2);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'new-keeper-snapshot',
            requestId: channel.sent.whereType<AdmissionRosterRequest>().last.id,
            senderIdentity: 'new-keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 11,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(client.roster!.revision).equals(11);
      check(client.roster!.members).deepEquals(['guest', 'other']);
    },
  );

  test(
    'keeper roster store survives same-process controller reattach',
    () async {
      final store = KeeperAdmissionRosterStore(keeperGeneration: 'generation')
        ..replace(const ['guest'], 2);
      final firstChannel = _Channel('keeper');
      final first = _keeperAdmissionController(
        channel: firstChannel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
      );
      check(first.roster).deepEquals(['guest']);
      check(first.rosterRevision).equals(2);
      firstChannel.controller.add(
        AdmissionPacketReceived(
          AdmissionRequest(
            id: 'return',
            senderIdentity: 'guest',
            recipientIdentity: 'keeper',
            expiresAt: _fixedNow.add(AdmissionProtocol.requestLifetime),
            displayName: 'Guest',
          ),
        ),
      );
      await pumpEventQueue();
      check(first.roster).isEmpty();
      await first.dispose();
      await firstChannel.dispose();

      final nextChannel = _Channel('keeper');
      final next = _keeperAdmissionController(
        channel: nextChannel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        rosterStore: store,
      );
      addTearDown(() async {
        await next.dispose();
        await nextChannel.dispose();
      });
      check(next.keeperGeneration).equals('generation');
      check(next.roster).isEmpty();
      check(store.members).contains('guest');
      check(next.rosterRevision).equals(3);
    },
  );

  test(
    'overlapping updates coalesce behind an in-flight roster snapshot',
    () async {
      final channel = _Channel('guest')..present.add('keeper');
      var nextId = 0;
      final client = _clientAdmissionRosterController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        sessionIdentity: 'session',
        newId: () => 'request-${++nextId}',
      );
      addTearDown(() async {
        await client.dispose();
        await channel.dispose();
      });
      final expiry = _fixedNow.add(const Duration(minutes: 1));
      final update = AdmissionRosterUpdated(
        id: 'update-first',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: expiry,
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: 1,
        members: const ['guest'],
      );
      final laterUpdate = AdmissionRosterUpdated(
        id: 'update-later',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: expiry,
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: 2,
        members: const ['guest', 'other'],
      );
      final changes = <AdmissionRoster?>[];
      final subscription = client.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      channel.controller
        ..add(AdmissionPacketReceived(update))
        ..add(AdmissionPacketReceived(laterUpdate))
        ..add(AdmissionPacketReceived(update));
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(1);
      check(client.roster).isNull();
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'snapshot-0',
            requestId: 'request-1',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 0,
            members: const ['guest', 'removed'],
          ),
        ),
      );
      check(client.roster).isNull();
      await pumpEventQueue();
      check(changes).isEmpty();
      check(client.isSynchronizing).isTrue();
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(2);
      channel.controller.add(
        AdmissionPacketReceived(
          AdmissionRosterSnapshot(
            id: 'snapshot-1',
            requestId: 'request-2',
            senderIdentity: 'keeper',
            recipientIdentity: 'guest',
            expiresAt: expiry,
            sessionIdentity: 'session',
            keeperGeneration: 'generation',
            revision: 2,
            members: const ['guest', 'other'],
          ),
        ),
      );
      check(client.roster!.members).deepEquals(['guest', 'other']);
      check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(2);
    },
  );

  test(
    'conflicting unverified generations require a newer correlated snapshot',
    () {
      fakeAsync((async) {
        final h = _RosterRetryHarness(async);
        final changes = <AdmissionRoster?>[];
        final subscription = h.client.changes.listen(changes.add);
        void update(String generation, int revision) {
          h.channel.controller.add(
            AdmissionPacketReceived(
              AdmissionRosterUpdated(
                id: 'update-$generation',
                senderIdentity: 'keeper',
                recipientIdentity: 'guest',
                expiresAt: h.now().add(const Duration(minutes: 1)),
                sessionIdentity: 'session',
                keeperGeneration: generation,
                revision: revision,
                members: const ['guest'],
              ),
            ),
          );
        }

        void snapshot(
          AdmissionRosterRequest request,
          String generation,
          int revision,
        ) {
          h.channel.controller.add(
            AdmissionPacketReceived(
              AdmissionRosterSnapshot(
                id: 'snapshot-$generation',
                requestId: request.id,
                senderIdentity: 'keeper',
                recipientIdentity: 'guest',
                expiresAt: h.now().add(const Duration(minutes: 1)),
                sessionIdentity: 'session',
                keeperGeneration: generation,
                revision: revision,
                members: const ['guest', 'other'],
              ),
            ),
          );
          async.flushMicrotasks();
        }

        final original = h.requests.single;
        update('B', 2);
        update('A', 5);
        check(h.requests).length.equals(2);
        snapshot(original, 'A', 5);
        check(h.client.roster).isNull();
        check(changes).isEmpty();
        snapshot(h.requests.last, 'B', 1);
        check(h.client.roster).isNull();
        check(h.client.isSynchronizing).isTrue();
        snapshot(h.requests.last, 'B', 2);
        check(h.client.roster!.keeperGeneration).equals('B');
        check(h.client.contains('other')).isTrue();
        unawaited(subscription.cancel());
        h.close();
      });
    },
  );

  test(
    'lost requests and responses retry with backoff until a current snapshot arrives',
    () {
      fakeAsync((async) {
        final h = _RosterRetryHarness(async);
        // No peer receives the initial request; later requests receive no response.
        final first = h.requests.single;
        final firstDelay = h.waitForRequest(2);
        final secondDelay = h.waitForRequest(3);
        final thirdDelay = h.waitForRequest(4);
        check(secondDelay > firstDelay).isTrue();
        check(thirdDelay > secondDelay).isTrue();
        check(h.requests.map((request) => request.id).toSet()).length.equals(4);
        check(h.client.roster).isNull();

        h.snapshot(first);
        h.snapshot(h.requests[1]);
        check(h.client.roster).isNull();
        h.snapshot(h.requests.last);
        check(h.client.contains('guest')).isTrue();
        for (var count = 5; count <= 16; count++) {
          async.elapse(const Duration(seconds: 20));
          check(h.requests).length.equals(count - 1);
          h.waitForRequest(count);
          h.snapshot(h.requests.last);
          check(h.client.contains('guest')).isTrue();
        }
        h.close();
      });
    },
  );

  test(
    'roster evidence excludes retries and invalidates on generation change',
    () {
      fakeAsync((async) {
        final h = _RosterRetryHarness(async);
        final changes = <AdmissionRoster?>[];
        final subscription = h.client.changes.listen(changes.add);
        h.snapshot(h.requests.single);
        check(changes).length.equals(1);

        h.channel.controller.add(const AdmissionConnectionRestored());
        h.waitForRequest(3);
        check(h.client.contains('guest')).isTrue();
        check(changes).length.equals(1);
        final oldRequest = h.requests.last;
        h.channel.controller.add(
          AdmissionPacketReceived(
            AdmissionRosterUpdated(
              id: 'new-generation',
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: h.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'new-generation',
              revision: 2,
              members: const ['guest'],
            ),
          ),
        );
        async.flushMicrotasks();
        check(h.client.roster).isNull();
        check(changes.last).isNull();
        h.channel.controller.add(
          AdmissionPacketReceived(
            AdmissionRosterUpdated(
              id: 'delayed-old-generation',
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: h.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'generation',
              revision: 99,
              members: const ['guest', 'removed'],
            ),
          ),
        );
        h.snapshot(oldRequest);
        h.snapshot(h.requests.last);
        check(h.client.roster).isNull();
        h.channel.controller.add(
          AdmissionPacketReceived(
            AdmissionRosterSnapshot(
              id: 'new-snapshot',
              requestId: h.requests.last.id,
              senderIdentity: 'keeper',
              recipientIdentity: 'guest',
              expiresAt: h.now().add(const Duration(minutes: 1)),
              sessionIdentity: 'session',
              keeperGeneration: 'new-generation',
              revision: 2,
              members: const ['guest'],
            ),
          ),
        );
        async.flushMicrotasks();
        check(h.client.contains('guest')).isTrue();
        check(changes).length.equals(3);
        unawaited(subscription.cancel());
        h.close();
      });
    },
  );

  test('explicit synchronization coalesces and waits for roster evidence', () {
    fakeAsync((async) {
      final h = _RosterRetryHarness(async);
      final changes = <AdmissionRoster?>[];
      final subscription = h.client.changes.listen(changes.add);
      h.client.requestSynchronization();
      check(h.requests).length.equals(1);
      h.snapshot(h.requests.single);
      check(changes).length.equals(1);

      h.client.requestSynchronization();
      h.client.requestSynchronization();
      async.flushMicrotasks();
      check(h.requests).length.equals(2);
      check(h.client.isSynchronizing).isTrue();
      check(changes).length.equals(1);
      h.snapshot(h.requests.last);
      check(changes).length.equals(2);
      check(h.client.isSynchronizing).isFalse();
      unawaited(subscription.cancel());
      h.close();
    });
  });

  test('failed sends continue retrying without a recovery event', () {
    fakeAsync((async) {
      final h = _RosterRetryHarness(async);
      h.channel.beforeSend = (_) async => throw StateError('offline');
      h
        ..waitForRequest(2)
        ..waitForRequest(3);
      h.channel.beforeSend = null;
      h.waitForRequest(4);
      h.snapshot(h.requests.last);
      check(h.client.contains('guest')).isTrue();
      async.elapse(const Duration(seconds: 20));
      check(h.requests).length.equals(4);
      h.close();
    });
  });

  for (final signal in ['presence', 'connection', 'hello']) {
    test('roster retries recover on $signal after a failed send', () {
      fakeAsync((async) {
        final h = _RosterRetryHarness(async);
        h.channel.beforeSend = (_) async => throw StateError('offline');
        h.waitForRequest(2);
        async.flushMicrotasks();
        h.channel.beforeSend = null;
        switch (signal) {
          case 'presence':
            h.channel.controller.add(
              const AdmissionPresenceChanged('keeper', true),
            );
          case 'connection':
            h.channel.controller.add(const AdmissionConnectionRestored());
          case 'hello':
            h.channel.controller.add(
              AdmissionPacketReceived(
                AdmissionHello(
                  id: 'hello',
                  senderIdentity: 'keeper',
                  recipientIdentity: 'guest',
                  expiresAt: h.now().add(const Duration(minutes: 1)),
                ),
              ),
            );
        }
        async.flushMicrotasks();
        check(h.requests).length.equals(3);
        h.snapshot(h.requests.last);
        check(h.client.contains('guest')).isTrue();
        async.elapse(const Duration(seconds: 20));
        check(h.requests).length.equals(3);
        h.close();
      });
    });
  }

  test('retry pauses while keeper is absent and resumes on presence', () {
    fakeAsync((async) {
      final h = _RosterRetryHarness(async);
      h.channel.present.remove('keeper');
      h.channel.controller.add(const AdmissionPresenceChanged('keeper', false));
      async.elapse(const Duration(minutes: 5));
      check(h.requests).length.equals(1);
      h.channel.present.add('keeper');
      h.channel.controller.add(const AdmissionPresenceChanged('keeper', true));
      async.flushMicrotasks();
      check(h.requests).length.equals(2);
      h.snapshot(h.requests.last);
      check(h.client.contains('guest')).isTrue();
      h.close();
    });
  });

  test('keeper switch invalidates old requests and retries the new keeper', () {
    fakeAsync((async) {
      final h = _RosterRetryHarness(async);
      final oldRequest = h.requests.single;
      h.channel.present.add('new-keeper');
      h.keeper = 'new-keeper';
      h.channel.controller.add(
        const AdmissionPresenceChanged('new-keeper', true),
      );
      async.flushMicrotasks();
      check(h.requests).length.equals(2);
      check(h.requests.last.recipientIdentity).equals('new-keeper');
      h.snapshot(oldRequest);
      check(h.client.roster).isNull();
      final staleNewRequest = h.requests.last;
      h.waitForRequest(3);
      check(h.requests.last.recipientIdentity).equals('new-keeper');
      h.snapshot(staleNewRequest);
      check(h.client.roster).isNull();
      h.snapshot(h.requests.last);
      check(h.client.contains('guest')).isTrue();
      h.close();
    });
  });

  for (final end in ['room end', 'dispose']) {
    test('roster retries stop on $end', () {
      fakeAsync((async) {
        final h = _RosterRetryHarness(async)..waitForRequest(2);
        if (end == 'room end') {
          h.channel.controller.add(const AdmissionRoomEnded());
        } else {
          unawaited(h.client.dispose());
          async.flushMicrotasks();
        }
        async.elapse(const Duration(minutes: 5));
        check(h.requests).length.equals(2);
        h.close();
      });
    });
  }

  test('delayed send failure after disposal does not schedule a retry', () {
    fakeAsync((async) {
      final h = _RosterRetryHarness(async);
      final send = Completer<void>();
      h.channel.beforeSend = (_) => send.future;
      h.waitForRequest(2);
      unawaited(h.client.dispose());
      async.flushMicrotasks();
      check(async.pendingTimers).isEmpty();
      send.completeError(StateError('offline'));
      async.flushMicrotasks();
      check(async.pendingTimers).isEmpty();
      async.elapse(const Duration(minutes: 5));
      check(h.requests).length.equals(2);
      h.close();
    });
  });

  test('failed roster request retries on the next presence signal', () async {
    final channel = _Channel('guest')..present.add('keeper');
    var nextId = 0;
    channel.beforeSend = (_) async => throw StateError('offline');
    final client = _clientAdmissionRosterController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      sessionIdentity: 'session',
      newId: () => 'request-${++nextId}',
    );
    addTearDown(() async {
      await client.dispose();
      await channel.dispose();
    });
    for (var i = 0; i < 5; i++) {
      await Future<void>.value();
    }
    channel.beforeSend = null;
    channel.controller.add(const AdmissionPresenceChanged('keeper', true));
    for (var i = 0; i < 5; i++) {
      await Future<void>.value();
    }
    check(channel.sent.whereType<AdmissionRosterRequest>()).length.equals(2);
  });

  test(
    'permanent denial saves before sending and remains retryable on failure',
    () async {
      var now = _fixedNow;
      final channel = _Channel('keeper', now: () => now);
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        now: () => now,
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      AdmissionRequest request(String id) => AdmissionRequest(
        id: id,
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: now.add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );

      final first = request('first');
      channel.controller.add(AdmissionPacketReceived(first));
      final saved = Completer<void>();
      final denial = keeper.denyPermanently(
        first.id,
        'guest',
        () => saved.future,
      );
      check(channel.sent.whereType<AdmissionDecision>()).isEmpty();
      await check(keeper.deny(first.id, 'guest')).throws<StateError>();
      saved.complete();
      await denial;
      check(
        channel.sent.whereType<AdmissionDecision>().single.approved,
      ).isFalse();

      now = now.add(const Duration(milliseconds: 1));
      final second = request('second');
      channel.controller.add(AdmissionPacketReceived(second));
      await check(
        keeper.denyPermanently(second.id, 'guest', () async {
          throw StateError('storage unavailable');
        }),
      ).throws<StateError>();
      check(keeper.requests.single.id).equals(second.id);
      check(
        channel.sent.whereType<AdmissionDecision>().where(
          (d) => d.id == second.id,
        ),
      ).isEmpty();
      await keeper.denyPermanently(second.id, 'guest', () async {});
      check(
        channel.sent.whereType<AdmissionDecision>().last.id,
      ).equals(second.id);
    },
  );

  test('blocked identities are denied automatically until removed', () async {
    final channel = _Channel('keeper');
    final keeper = _keeperAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      declinedIdentities: {'guest'},
    );
    addTearDown(() async {
      await keeper.dispose();
      await channel.dispose();
    });
    AdmissionRequest request(String id, int offset) => AdmissionRequest(
      id: id,
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: _fixedNow.add(Duration(minutes: offset)),
      displayName: 'Guest',
    );

    final first = request('first', 1);
    channel.controller.add(AdmissionPacketReceived(first));
    await pumpEventQueue();
    check(keeper.requests).isEmpty();
    check(
      channel.sent.whereType<AdmissionDecision>().single.approved,
    ).isFalse();
    await check(keeper.approve(first.id, 'guest')).throws<StateError>();

    final second = request('second', 2);
    channel.controller.add(AdmissionPacketReceived(second));
    await pumpEventQueue();
    check(keeper.requests).isEmpty();
    check(channel.sent.whereType<AdmissionDecision>()).length.equals(2);
    check(
      channel.sent.whereType<AdmissionDecision>().last.id,
    ).equals(second.id);
    check(channel.sent.whereType<AdmissionDecision>().last.approved).isFalse();

    keeper.setDeclinedIdentities({});
    channel.controller.add(AdmissionPacketReceived(second));
    await pumpEventQueue();
    check(channel.sent.whereType<AdmissionDecision>()).length.equals(3);
    check(
      channel.sent.whereType<AdmissionDecision>().last.id,
    ).equals(second.id);
    check(channel.sent.whereType<AdmissionDecision>().last.approved).isFalse();

    final third = request('third', 3);
    channel.controller.add(AdmissionPacketReceived(third));
    check(keeper.requests.single.id).equals(third.id);
    await keeper.approve(third.id, 'guest');
    check(channel.sent.whereType<AdmissionDecision>().last.approved).isTrue();
  });

  test(
    'blocklist updates override open admission and reject a superseded save',
    () async {
      final channel = _Channel('keeper');
      final keeper = _keeperAdmissionController(
        channel: channel,
        keeperIdentity: () => 'keeper',
        approvalRequired: false,
      );
      addTearDown(() async {
        await keeper.dispose();
        await channel.dispose();
      });
      final first = AdmissionRequest(
        id: 'first',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: _fixedNow.add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      keeper.setDeclinedIdentities({'guest'});
      channel.controller.add(AdmissionPacketReceived(first));
      await pumpEventQueue();
      check(keeper.requests).isEmpty();
      check(
        channel.sent.whereType<AdmissionDecision>().single.approved,
      ).isFalse();

      keeper
        ..setDeclinedIdentities({})
        ..setApprovalRequired(true);
      final pending = AdmissionRequest(
        id: 'pending',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: _fixedNow.add(const Duration(minutes: 2)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(pending));
      final saved = Completer<void>();
      final denial = keeper.denyPermanently(
        pending.id,
        'guest',
        () => saved.future,
      );
      final replacement = AdmissionRequest(
        id: 'replacement',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: _fixedNow.add(const Duration(minutes: 3)),
        displayName: 'Guest',
      );
      channel.controller.add(AdmissionPacketReceived(replacement));
      saved.complete();
      await check(denial).throws<StateError>();
      check(keeper.requests.single.id).equals(replacement.id);
      check(
        channel.sent.whereType<AdmissionDecision>().where(
          (decision) => decision.id == pending.id,
        ),
      ).isEmpty();
    },
  );

  test('permanent decline denies a participant who is also revoked', () async {
    final channel = _Channel('keeper');
    final store = KeeperAdmissionRosterStore()..revoked.add('guest');
    final keeper = _keeperAdmissionController(
      channel: channel,
      keeperIdentity: () => 'keeper',
      sessionIdentity: 'session',
      rosterStore: store,
    );
    addTearDown(() async {
      await keeper.dispose();
      await channel.dispose();
    });

    keeper.setDeclinedIdentities({'guest'});
    final request = AdmissionRequest(
      id: 'revoked-and-declined',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: _fixedNow.add(const Duration(minutes: 1)),
      displayName: 'Guest',
    );
    channel.controller.add(AdmissionPacketReceived(request));
    await pumpEventQueue();

    final decision = channel.sent.whereType<AdmissionDecision>().single;
    check(decision.id).equals(request.id);
    check(decision.approved).isFalse();
    check(keeper.requests).isEmpty();
    check(keeper.attempts.single.status).equals(KeeperAdmissionStatus.denied);
  });
}
