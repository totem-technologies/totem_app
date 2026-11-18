import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/admission/session_admission_channel.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../transport/fake_session_transport.dart';

final _now = DateTime.utc(2026, 1, 1);
const _keeper = ParticipantInfo(
  sid: 'keeper-sid',
  identity: 'keeper',
  name: 'Keeper',
);
const _guest = ParticipantInfo(
  sid: 'guest-sid',
  identity: 'guest',
  name: 'Guest',
  isLocal: true,
);
const _other = ParticipantInfo(
  sid: 'other-sid',
  identity: 'other',
  name: 'Other',
);

class _ObservedTransport extends FakeSessionTransport {
  int eventStreamReads = 0;
  @override
  Stream<SessionTransportEvent> get events {
    eventStreamReads++;
    return super.events;
  }
}

_ObservedTransport _connection() => _ObservedTransport()
  ..localIdentity = 'guest'
  ..connectionState = SessionTransportConnectionState.connected
  ..participants = const [_guest, _keeper];

AdmissionRequest _request({DateTime? expiresAt}) => AdmissionRequest(
  id: 'request',
  senderIdentity: 'guest',
  recipientIdentity: 'keeper',
  expiresAt: expiresAt ?? _now.add(const Duration(minutes: 1)),
  displayName: 'Guest',
);
AdmissionHello _hello() => AdmissionHello(
  id: 'hello',
  senderIdentity: 'keeper',
  recipientIdentity: 'guest',
  expiresAt: _now.add(const Duration(minutes: 1)),
);
AdmissionRosterUpdated _roster() => AdmissionRosterUpdated(
  id: 'roster',
  senderIdentity: 'keeper',
  recipientIdentity: 'guest',
  expiresAt: _now.add(const Duration(minutes: 1)),
  sessionIdentity: 'session',
  keeperGeneration: 'generation',
  revision: 1,
  members: const ['guest'],
);
TransportPacketReceived _received(
  AdmissionPacket packet, {
  ParticipantInfo? sender = _keeper,
  String topic = AdmissionProtocol.topic,
}) => TransportPacketReceived(
  SessionTransportPacket(
    bytes: AdmissionProtocol.encode(packet),
    topic: topic,
    sender: sender,
  ),
);

void main() {
  test(
    'channel publishes typed admission packets reliably to their single recipient',
    () async {
      final connection = _connection();
      final channel = SessionAdmissionChannel(connection, now: () => _now);
      try {
        await channel.send(_request());
        final published = connection.publications.single;
        check(published.topic).equals(AdmissionProtocol.topic);
        check(published.reliable).isTrue();
        check(published.recipients).deepEquals(['keeper']);
        final packet = AdmissionProtocol.decode(
          published.bytes,
          senderIdentity: 'guest',
          now: _now,
        );
        check(packet).isA<AdmissionRequest>();
        check(packet?.id).equals('request');
        check(channel.remoteIdentities).deepEquals(['keeper']);
        check(channel.isPresent('keeper')).isTrue();
        check(channel.isPresent('guest')).isFalse();
      } finally {
        await channel.dispose();
        await connection.dispose();
      }
    },
  );

  test(
    'only valid admission packets with transport-authenticated senders are received',
    () async {
      final connection = _connection();
      final channel = SessionAdmissionChannel(connection, now: () => _now);
      final events = <AdmissionEvent>[];
      final subscription = channel.events.listen(events.add);
      try {
        channel
          ..handle(_received(_hello(), topic: 'lk-chat-topic'))
          ..handle(_received(_hello(), sender: _other))
          ..handle(_received(_hello(), sender: null))
          ..handle(
            TransportPacketReceived(
              SessionTransportPacket(
                bytes: [0xff],
                topic: AdmissionProtocol.topic,
                sender: _keeper,
              ),
            ),
          )
          ..handle(_received(_hello()));

        check(events).length.equals(1);
        final packet = (events.single as AdmissionPacketReceived).packet;
        check(packet).isA<AdmissionHello>();
        check(packet.senderIdentity).equals('keeper');
        check(packet.recipientIdentity).equals('guest');
      } finally {
        await subscription.cancel();
        await channel.dispose();
        await connection.dispose();
      }
    },
  );

  test(
    'presence and reconnect are translated without another transport subscription or owner',
    () async {
      final connection = _connection();
      final channel = SessionAdmissionChannel(connection, now: () => _now);
      final events = <AdmissionEvent>[];
      final subscription = channel.events.listen(events.add);
      channel
        ..handle(const TransportParticipantChanged(_keeper, present: false))
        ..handle(const TransportParticipantChanged(_keeper, present: true))
        ..handle(
          const TransportConnectionChanged(
            SessionTransportConnectionState.reconnecting,
          ),
        )
        ..handle(
          const TransportConnectionChanged(
            SessionTransportConnectionState.connected,
            reconnected: true,
          ),
        )
        ..handle(
          const TransportConnectionChanged(
            SessionTransportConnectionState.disconnected,
            reason: SessionTransportDisconnectReason.connectionTimeout,
          ),
        );

      check(
        events.whereType<AdmissionPresenceChanged>().map(
          (event) => (event.identity, event.present),
        ),
      ).deepEquals([('keeper', false), ('keeper', true)]);
      check(
        events.whereType<AdmissionConnectionInterrupted>(),
      ).length.equals(1);
      check(events.whereType<AdmissionConnectionRestored>()).length.equals(1);
      check(
        events.whereType<AdmissionRoomDisconnected>().single.reason,
      ).equals(SessionTransportDisconnectReason.connectionTimeout);
      await subscription.cancel();
      await channel.dispose();
      await channel.dispose();
      check(connection.eventStreamReads).equals(0);
      check(connection.disconnectCalls).equals(0);
      check(connection.underlyingDisposals).equals(0);
      await connection.dispose();
      check(connection.underlyingDisposals).equals(1);
    },
  );

  test(
    'sender identity mismatch and disconnected publication fail without sending',
    () async {
      final connection = _connection();
      final channel = SessionAdmissionChannel(connection, now: () => _now);
      try {
        final impersonated = AdmissionRequest(
          id: 'request',
          senderIdentity: 'other',
          recipientIdentity: 'keeper',
          expiresAt: _now.add(const Duration(minutes: 1)),
          displayName: 'Other',
        );
        await check(channel.send(impersonated)).throws<StateError>();
        connection.connectionState =
            SessionTransportConnectionState.disconnected;
        await check(channel.send(_request())).throws<StateError>();
        check(connection.publications).isEmpty();
      } finally {
        await channel.dispose();
        await connection.dispose();
      }
    },
  );

  test(
    'Keeper hello, presence, reconnect, and one timed retry resend the same correlated outcome',
    () {
      fakeAsync((clock) {
        final connection = _connection();
        final channel = SessionAdmissionChannel(
          connection,
          now: () => _now.add(clock.elapsed),
        );
        var sent = false;
        unawaited(channel.sendJoinOutcome(_request()).then((_) => sent = true));
        clock.flushMicrotasks();
        check(sent).isTrue();
        check(connection.publications).length.equals(1);
        channel.handle(_received(_hello(), sender: _other));
        check(connection.publications).length.equals(1);
        channel
          ..handle(_received(_hello()))
          ..handle(const TransportParticipantChanged(_keeper, present: true))
          ..handle(
            const TransportConnectionChanged(
              SessionTransportConnectionState.connected,
              reconnected: true,
            ),
          );
        clock.flushMicrotasks();
        check(connection.publications).length.equals(4);
        clock
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();
        check(connection.publications).length.equals(5);
        for (final publication in connection.publications) {
          final packet = AdmissionProtocol.decode(
            publication.bytes,
            senderIdentity: 'guest',
            now: _now.add(clock.elapsed),
          );
          check(packet).isA<AdmissionJoined>();
          check(packet?.id).equals('request');
          check(packet?.recipientIdentity).equals('keeper');
          check(publication.recipients).deepEquals(['keeper']);
        }
        unawaited(channel.dispose());
        unawaited(connection.dispose());
        clock.flushMicrotasks();
      });
    },
  );

  test(
    'Keeper roster confirmation cancels timed and reconnect-driven resends',
    () {
      fakeAsync((clock) {
        final connection = _connection();
        final channel = SessionAdmissionChannel(
          connection,
          now: () => _now.add(clock.elapsed),
        );
        unawaited(channel.sendJoinOutcome(_request()));
        clock.flushMicrotasks();
        channel.handle(_received(_roster()));
        clock.elapse(const Duration(seconds: 3));
        channel
          ..handle(_received(_hello()))
          ..handle(
            const TransportConnectionChanged(
              SessionTransportConnectionState.connected,
              reconnected: true,
            ),
          );
        clock.flushMicrotasks();
        check(connection.publications).length.equals(1);
        check(clock.nonPeriodicTimerCount).equals(0);
        unawaited(channel.dispose());
        unawaited(connection.dispose());
        clock.flushMicrotasks();
      });
    },
  );

  test('publication failure retains the outcome for a Keeper-driven retry', () {
    fakeAsync((clock) {
      final connection = _connection()..publishFailure = Exception('offline');
      final channel = SessionAdmissionChannel(
        connection,
        now: () => _now.add(clock.elapsed),
      );
      var failed = false;
      unawaited(
        check(
          channel.sendJoinOutcome(_request()),
        ).throws<Exception>().then((_) => failed = true),
      );
      clock.flushMicrotasks();
      check(failed).isTrue();
      connection.publishFailure = null;
      channel.handle(_received(_hello()));
      clock.flushMicrotasks();
      check(connection.publications).length.equals(1);
      check(
        AdmissionProtocol.decode(
          connection.publications.single.bytes,
          senderIdentity: 'guest',
          now: _now,
        ),
      ).isA<AdmissionJoined>();
      unawaited(channel.dispose());
      unawaited(connection.dispose());
      clock.flushMicrotasks();
    });
  });

  test(
    'disposal cancels outcome retries and ignores late events without disposing the room',
    () {
      fakeAsync((clock) {
        final connection = _connection();
        final channel = SessionAdmissionChannel(
          connection,
          now: () => _now.add(clock.elapsed),
        );
        unawaited(channel.sendJoinOutcome(_request(), joined: false));
        clock.flushMicrotasks();
        check(
          AdmissionProtocol.decode(
            connection.publications.single.bytes,
            senderIdentity: 'guest',
            now: _now,
          ),
        ).isA<AdmissionJoinFailed>();
        unawaited(channel.dispose());
        clock
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 5));
        channel
          ..handle(_received(_hello()))
          ..handle(
            const TransportConnectionChanged(
              SessionTransportConnectionState.connected,
              reconnected: true,
            ),
          );
        clock.flushMicrotasks();
        check(connection.publications).length.equals(1);
        check(connection.disconnectCalls).equals(0);
        check(connection.underlyingDisposals).equals(0);
        check(clock.nonPeriodicTimerCount).equals(0);
        unawaited(connection.dispose());
        clock.flushMicrotasks();
      });
    },
  );

  test(
    'canonical ended metadata stops receipt recovery and prevents reconnect readiness',
    () async {
      final connection = _connection();
      final channel = SessionAdmissionChannel(connection, now: () => _now);
      final events = <AdmissionEvent>[];
      final subscription = channel.events.listen(events.add);
      const ended = RoomState(
        sessionSlug: 'session',
        version: 2,
        status: RoomStatus.ended,
        turnState: TurnState.idle,
        statusDetail: RoomStateStatusDetailEnded(
          EndedDetail(reason: EndReason.keeperEnded),
        ),
        talkingOrder: [],
        keeper: 'keeper',
        roundNumber: 1,
      );
      try {
        channel
          ..handle(const TransportMetadataChanged('malformed'))
          ..handle(TransportMetadataChanged(jsonEncode(ended.toJson())))
          ..handle(
            const TransportConnectionChanged(
              SessionTransportConnectionState.connected,
              reconnected: true,
            ),
          );
        check(channel.hasEnded).isTrue();
        check(events.whereType<AdmissionRoomEnded>()).length.equals(1);
        check(events.whereType<AdmissionConnectionRestored>()).isEmpty();
        await check(channel.sendJoinOutcome(_request())).throws<StateError>();
      } finally {
        await subscription.cancel();
        await channel.dispose();
        await connection.dispose();
      }
    },
  );
}
