import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/services/session_chat_service.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../transport/fake_session_transport.dart';

const _keeper = ParticipantInfo(
  sid: 'keeper-sid',
  identity: 'keeper',
  name: 'Keeper',
);
const _participant = ParticipantInfo(
  sid: 'participant-sid',
  identity: 'participant',
  name: 'Participant',
);
const _other = ParticipantInfo(
  sid: 'other-sid',
  identity: 'other',
  name: 'Other',
);

SessionTransportPacket _packet({
  String id = 'message',
  ParticipantInfo? sender = _keeper,
  String? recipient,
  int timestamp = 100,
  String topic = 'lk-chat-topic',
}) => SessionTransportPacket(
  topic: topic,
  sender: sender,
  bytes: utf8.encode(
    jsonEncode({
      'message': 'Hello',
      'id': id,
      'timestamp': timestamp,
      'recipientIdentity': ?recipient,
    }),
  ),
);

class _GatedTransport extends FakeSessionTransport {
  final started = Completer<void>();
  final completion = Completer<void>();

  @override
  Future<void> publish(SessionTransportPacket packet) async {
    started.complete();
    await completion.future;
    await super.publish(packet);
  }
}

class _Harness {
  _Harness({this.keeper = false, FakeSessionTransport? transport}) {
    connection = transport ?? FakeSessionTransport();
    connection!
      ..localIdentity = keeper ? 'keeper' : 'participant'
      ..connectionState = SessionTransportConnectionState.connected
      ..participants = [_keeper, _participant, _other];
    service = SessionChatService(
      transport: () => connection,
      keeperIdentity: () => 'keeper',
      isKeeper: () => keeper,
      now: () => DateTime.fromMillisecondsSinceEpoch(1234),
      createId: () => 'outgoing-${_ids++}',
    );
  }

  final bool keeper;
  int _ids = 0;
  FakeSessionTransport? connection;
  late final SessionChatService service;

  Future<void> dispose() async {
    service.dispose();
    await connection?.dispose();
  }
}

void main() {
  test(
    'Keeper broadcasts reliably and sends private packets only to their recipient',
    () async {
      final h = _Harness(keeper: true);
      addTearDown(h.dispose);

      check(await h.service.send('For everyone')).equals(ChatSendOutcome.sent);
      check(
        await h.service.send(
          'For one person',
          recipientIdentity: 'participant',
        ),
      ).equals(ChatSendOutcome.sent);

      final publications = h.connection!.publications;
      check(publications).length.equals(2);
      check(publications.every((packet) => packet.reliable)).isTrue();
      check(
        publications.every(
          (packet) => packet.topic == SessionCommunicationTopics.chat.topic,
        ),
      ).isTrue();
      check(publications.first.recipients).isEmpty();
      check(publications.last.recipients).deepEquals(['participant']);
      final payload =
          jsonDecode(utf8.decode(publications.last.bytes))
              as Map<String, dynamic>;
      check(payload['recipientIdentity']).equals('participant');
      check(payload['id']).equals('outgoing-1');
      check(payload['timestamp']).equals(1234);
      check(
        h.service.messages.map((message) => message.message),
      ).deepEquals(['For everyone', 'For one person']);
    },
  );

  test(
    'participants can send privately to the Keeper, but cannot broadcast or address another participant',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);

      check(
        await h.service.send('Broadcast'),
      ).equals(ChatSendOutcome.unauthorized);
      check(
        await h.service.send('Wrong recipient', recipientIdentity: 'other'),
      ).equals(ChatSendOutcome.invalidRecipient);
      check(
        await h.service.send('For Keeper', recipientIdentity: 'keeper'),
      ).equals(ChatSendOutcome.sent);

      check(h.connection!.publications).length.equals(1);
      check(
        h.connection!.publications.single.recipients,
      ).deepEquals(['keeper']);
      check(h.service.messages.single.recipientIdentity).equals('keeper');
    },
  );

  test('Keeper cannot send to themselves or a departed participant', () async {
    final h = _Harness(keeper: true);
    addTearDown(h.dispose);

    check(
      await h.service.send('Self', recipientIdentity: 'keeper'),
    ).equals(ChatSendOutcome.invalidRecipient);
    check(
      await h.service.send('Missing', recipientIdentity: 'departed'),
    ).equals(ChatSendOutcome.invalidRecipient);
    h.connection!.participants = [_keeper, _other];
    check(
      await h.service.send('Left meanwhile', recipientIdentity: 'participant'),
    ).equals(ChatSendOutcome.invalidRecipient);

    check(h.connection!.publications).isEmpty();
    check(h.service.messages).isEmpty();
  });

  test(
    'publication failure preserves message history and exposes a retryable outcome',
    () async {
      final h = _Harness(keeper: true);
      addTearDown(h.dispose);
      final failure = Exception('transport unavailable');
      h.connection!.publishFailure = failure;

      check(await h.service.send('Retry me')).equals(ChatSendOutcome.failed);
      check(h.service.messages).isEmpty();
      check(h.service.lastError).identicalTo(failure);
      h.service.receive(
        SessionTransportPacket(
          topic: SessionCommunicationTopics.chat.topic,
          sender: _keeper,
          bytes: [0xff],
        ),
      );
      check(h.service.lastError).identicalTo(failure);

      h.connection!.publishFailure = null;
      check(await h.service.send('Retry me')).equals(ChatSendOutcome.sent);
      check(h.service.messages).length.equals(1);
      check(h.service.lastError).isNull();
    },
  );

  test(
    'disconnected and empty messages never publish or add local history',
    () async {
      final h = _Harness(keeper: true);
      addTearDown(h.dispose);

      check(await h.service.send('   ')).equals(ChatSendOutcome.invalidMessage);
      h.connection!.connectionState =
          SessionTransportConnectionState.disconnected;
      check(
        await h.service.send('Offline'),
      ).equals(ChatSendOutcome.disconnected);

      check(h.connection!.publications).isEmpty();
      check(h.service.messages).isEmpty();
    },
  );

  test(
    'Everyone receive validation rejects non-Keepers and unknown senders before deduplication',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);

      h.service
        ..receive(_packet(sender: _other))
        ..receive(_packet(sender: null))
        ..receive(_packet());

      check(h.service.messages).length.equals(1);
      check(h.service.messages.single.participant?.identity).equals('keeper');
      check(h.service.messages.single.isEveryoneThread).isTrue();
    },
  );

  test(
    'participant receives only private messages addressed to them by the Keeper',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);

      h.service
        ..receive(_packet(id: 'other-target', recipient: 'other'))
        ..receive(_packet(id: 'peer', sender: _other, recipient: 'participant'))
        ..receive(
          _packet(id: 'unknown', sender: null, recipient: 'participant'),
        )
        ..receive(_packet(id: 'accepted', recipient: 'participant'));

      check(
        h.service.messages.map((message) => message.id),
      ).deepEquals(['accepted']);
      check(
        h.service.messages.single.threadTargetFor('participant'),
      ).equals('keeper');
    },
  );

  test(
    'Keeper receives private participant messages only when addressed to the Keeper',
    () async {
      final h = _Harness(keeper: true);
      addTearDown(h.dispose);

      h.service
        ..receive(
          _packet(id: 'peer-target', sender: _participant, recipient: 'other'),
        )
        ..receive(_packet(id: 'self', recipient: 'keeper'))
        ..receive(
          _packet(id: 'accepted', sender: _participant, recipient: 'keeper'),
        );

      check(
        h.service.messages.map((message) => message.id),
      ).deepEquals(['accepted']);
      check(
        h.service.messages.single.threadTargetFor('keeper'),
      ).equals('participant');
    },
  );

  test(
    'duplicates do not notify and delayed timestamps preserve unread arrival order',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      var updates = 0;
      void changed() {
        updates++;
      }

      h.service.addListener(changed);
      addTearDown(() => h.service.removeListener(changed));

      h.service
        ..receive(_packet(id: 'newer', timestamp: 200))
        ..receive(_packet(id: 'older', timestamp: 100))
        ..receive(_packet(id: 'newer', timestamp: 200));

      check(
        h.service.messages.map((message) => message.id),
      ).deepEquals(['newer', 'older']);
      check(
        h.service.messages.map((message) => message.timestamp),
      ).deepEquals([200, 100]);
      check(updates).equals(2);
    },
  );

  test(
    'admission packets and malformed chat never enter chat history',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);

      h.service.receive(_packet(topic: AdmissionProtocol.topic));
      check(h.service.messages).isEmpty();
      check(h.service.lastError).isNull();
      h.service.receive(
        SessionTransportPacket(
          topic: SessionCommunicationTopics.chat.topic,
          sender: _keeper,
          bytes: [0xff],
        ),
      );
      check(h.service.messages).isEmpty();
      check(h.service.lastError).isNull();
    },
  );

  for (final end in ['cancel', 'replace', 'dispose']) {
    test('late send completion after $end cannot append or notify', () async {
      final transport = _GatedTransport();
      final h = _Harness(keeper: true, transport: transport);
      addTearDown(h.dispose);
      var updates = 0;
      h.service.addListener(() {
        updates++;
      });
      final send = h.service.send('In flight');
      await transport.started.future;
      switch (end) {
        case 'cancel':
          h.service.cancelPending();
        case 'replace':
          h.connection = FakeSessionTransport()
            ..connectionState = SessionTransportConnectionState.connected;
        case 'dispose':
          h.service.dispose();
      }
      transport.completion.complete();
      check(await send).equals(ChatSendOutcome.disconnected);
      check(h.service.messages).isEmpty();
      check(updates).equals(0);
      if (end == 'replace') await transport.dispose();
    });
  }
}
