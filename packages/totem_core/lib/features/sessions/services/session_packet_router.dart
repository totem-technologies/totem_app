import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),
  chat('lk-chat-topic'),
  participantRemoved('lk-participant-removed-topic');

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
  final void Function(SessionTransportPacket) chat;
  final void Function(SessionTransportPacket) reaction;
  final void Function(SessionTransportPacket) removal;
  final void Function(SessionTransportEvent) admission;

  void handle(SessionTransportEvent event) {
    if (event case TransportPacketReceived(:final packet)) {
      if (packet.topic == SessionCommunicationTopics.chat.topic) {
        chat(packet);
      } else if (packet.topic == SessionCommunicationTopics.emoji.topic) {
        reaction(packet);
      } else if (packet.topic ==
          SessionCommunicationTopics.participantRemoved.topic) {
        removal(packet);
      } else if (packet.topic == AdmissionProtocol.topic) {
        admission(event);
      }
    } else {
      admission(event);
    }
  }
}
