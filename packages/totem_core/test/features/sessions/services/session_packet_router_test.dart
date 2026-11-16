import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

void main() {
  test('each supported topic reaches exactly its feature owner', () {
    final chat = <SessionTransportPacket>[];
    final reactions = <SessionTransportPacket>[];
    final removals = <SessionTransportPacket>[];
    final admission = <SessionTransportEvent>[];
    final router = SessionPacketRouter(
      chat: chat.add,
      reaction: reactions.add,
      removal: removals.add,
      admission: admission.add,
    );
    final packets = [
      for (final topic in [
        SessionCommunicationTopics.chat.topic,
        SessionCommunicationTopics.emoji.topic,
        SessionCommunicationTopics.participantRemoved.topic,
        AdmissionProtocol.topic,
      ])
        SessionTransportPacket(bytes: [1, 2], topic: topic),
    ];

    for (final packet in packets) {
      router.handle(TransportPacketReceived(packet));
    }

    check(chat).length.equals(1);
    check(chat.single).identicalTo(packets[0]);
    check(reactions).length.equals(1);
    check(reactions.single).identicalTo(packets[1]);
    check(removals).length.equals(1);
    check(removals.single).identicalTo(packets[2]);
    check(admission).length.equals(1);
    check(
      (admission.single as TransportPacketReceived).packet,
    ).identicalTo(packets[3]);
  });

  test(
    'unknown topics cannot reach chat, admission, reactions, or moderation',
    () {
      final handled = <Object>[];
      SessionPacketRouter(
        chat: handled.add,
        reaction: handled.add,
        removal: handled.add,
        admission: handled.add,
      ).handle(
        TransportPacketReceived(
          SessionTransportPacket(bytes: [1], topic: 'unknown'),
        ),
      );

      check(handled).isEmpty();
    },
  );

  test(
    'presence, metadata, and reconnect events go to admission without decoding as messages',
    () {
      final handledMessages = <SessionTransportPacket>[];
      final admission = <SessionTransportEvent>[];
      final router = SessionPacketRouter(
        chat: handledMessages.add,
        reaction: handledMessages.add,
        removal: handledMessages.add,
        admission: admission.add,
      );
      const participant = ParticipantInfo(
        sid: 'participant-sid',
        identity: 'participant',
        name: 'Participant',
      );
      const events = <SessionTransportEvent>[
        TransportParticipantChanged(participant, present: true),
        TransportParticipantChanged(participant, present: false),
        TransportMetadataChanged('{"status":"ended"}'),
        TransportConnectionChanged(
          SessionTransportConnectionState.reconnecting,
        ),
        TransportConnectionChanged(
          SessionTransportConnectionState.connected,
          reconnected: true,
        ),
      ];

      events.forEach(router.handle);

      check(handledMessages).isEmpty();
      check(admission).deepEquals(events);
    },
  );
}
