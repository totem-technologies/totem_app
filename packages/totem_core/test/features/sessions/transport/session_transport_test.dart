import 'dart:async';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import 'fake_session_transport.dart';

void main() {
  test(
    'connection completion, failure, retry, and reconnect events are controlled',
    () async {
      final factory = FakeSessionTransportFactory(
        configure: (transport) =>
            transport.connectCompletion = Completer<void>(),
      );
      final transport = factory.create();
      final events = <SessionTransportEvent>[];
      final subscription = transport.events.listen(events.add);
      try {
        transport.connectFailure = const SessionTransportFailure(
          SessionTransportFailureKind.connection,
          'failed',
          cause: 'diagnostic',
          stackTrace: StackTrace.empty,
        );
        final first = transport.connect('url', 'token', autoSubscribe: false);
        check(
          transport.connectionState,
        ).equals(SessionTransportConnectionState.connecting);
        final failed = check(first).throws<SessionTransportFailure>();
        transport.connectCompletion!.complete();
        await failed;
        transport.connectFailure = null;
        await transport.connect('url', 'token', autoSubscribe: false);
        for (final state in [
          SessionTransportConnectionState.reconnecting,
          SessionTransportConnectionState.connected,
        ]) {
          transport.emit(TransportConnectionChanged(state));
        }
        await transport.disconnect();
        check(transport.connectCalls).equals(2);
        check(transport.autoSubscribe).equals(false);
        check(
          events
              .whereType<TransportConnectionChanged>()
              .map((e) => e.state)
              .toList(),
        ).deepEquals([
          SessionTransportConnectionState.connecting,
          SessionTransportConnectionState.disconnected,
          SessionTransportConnectionState.connecting,
          SessionTransportConnectionState.connected,
          SessionTransportConnectionState.reconnecting,
          SessionTransportConnectionState.connected,
          SessionTransportConnectionState.disconnected,
        ]);
      } finally {
        await subscription.cancel();
        await transport.dispose();
      }
    },
  );

  test(
    'data routing and permission changes retain application intent',
    () async {
      final transport = FakeSessionTransport();
      try {
        await transport.connect('url', 'token');
        final packet = SessionTransportPacket(
          bytes: [1, 2],
          topic: 'admission',
          reliable: true,
          recipients: ['keeper'],
        );
        await transport.publish(packet);
        transport.setSubscriptionPermissions(
          allowEveryone: false,
          recipients: {'keeper'},
        );
        await transport.subscribeToExistingMedia();
        check(transport.publications.single.reliable).isTrue();
        check(transport.publications.single.recipients).deepEquals(['keeper']);
        check(transport.recipients).deepEquals({'keeper'});
        transport.publishFailure = Exception('publication failed');
        await check(transport.publish(packet)).throws<Exception>();
        check(transport.publications).length.equals(1);
        const participant = ParticipantInfo(
          sid: 'remote',
          identity: 'keeper',
          name: 'Keeper',
        );
        transport.emit(
          const TransportParticipantChanged(participant, present: true),
        );
        check(transport.participants).deepEquals([participant]);
        transport.emit(const TransportMetadataChanged('room state'));
        check(transport.metadata).equals('room state');
        transport.emit(
          const TransportParticipantChanged(participant, present: false),
        );
        check(transport.participants).isEmpty();
      } finally {
        await transport.dispose();
      }
    },
  );

  test('claim transfers the existing connection exactly once', () async {
    final transport = FakeSessionTransport();
    await transport.connect('url', 'token');
    final lease = ConnectedSessionLease(transport);
    final claimed = lease.claim();
    check(identical(claimed, transport)).isTrue();
    check(lease.claim).throws<StateError>();
    await lease.dispose();
    check(transport.underlyingDisposals).equals(0);
    check(transport.connectCalls).equals(1);
    await claimed.dispose();
    await claimed.dispose();
    check(transport.underlyingDisposals).equals(1);
  });

  test('unclaimed or disconnected offers have a single cleanup path', () async {
    final transport = FakeSessionTransport();
    await transport.connect('url', 'token');
    final lease = ConnectedSessionLease(transport);
    await transport.disconnect();
    check(lease.claim).throws<StateError>();
    await lease.dispose();
    await lease.dispose();
    check(transport.underlyingDisposals).equals(1);
  });

  test('disposal fences events and pending connect completion', () async {
    final transport = FakeSessionTransport()
      ..connectCompletion = Completer<void>();
    final events = <SessionTransportEvent>[];
    final subscription = transport.events.listen(events.add);
    final connecting = transport.connect('url', 'token');
    final failed = check(connecting).throws<StateError>();
    await transport.dispose();
    final count = events.length;
    transport.emit(
      const TransportConnectionChanged(
        SessionTransportConnectionState.connected,
      ),
    );
    transport.connectCompletion!.complete();
    await failed;
    check(events).length.equals(count);
    await subscription.cancel();
  });
}
