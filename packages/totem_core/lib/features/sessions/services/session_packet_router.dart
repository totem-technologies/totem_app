import 'package:flutter/foundation.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),
  chat('lk-chat-topic'),
  participantRemoved('lk-participant-removed-topic'),
  admission('totem.admission.v2');

  const SessionCommunicationTopics(this.topic);
  final String topic;
}

/// Routes the existing protocols. The runtime remains the only subscriber.
class SessionPacketRouter {
  const SessionPacketRouter({
    required this.chat,
    required this.reaction,
    required this.removal,
    required this.admission,
  });
  final ValueSetter<SessionTransportPacket> chat;
  final ValueSetter<SessionTransportPacket> reaction;
  final ValueSetter<SessionTransportPacket> removal;
  final ValueSetter<SessionTransportEvent> admission;

  void handle(SessionTransportEvent event) {
    if (event case TransportPacketReceived(:final packet)) {
      if (packet.topic == SessionCommunicationTopics.chat.topic) {
        chat(packet);
      } else if (packet.topic == SessionCommunicationTopics.emoji.topic) {
        reaction(packet);
      } else if (packet.topic ==
          SessionCommunicationTopics.participantRemoved.topic) {
        removal(packet);
      } else if (packet.topic == SessionCommunicationTopics.admission.topic) {
        admission(event);
      }
    } else {
      admission(event);
    }
  }
}
