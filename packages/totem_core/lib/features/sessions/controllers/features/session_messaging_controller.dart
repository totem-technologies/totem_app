import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/services/session_chat_service.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

export 'package:totem_core/features/sessions/models/session_chat_message.dart';
export 'package:totem_core/features/sessions/services/session_packet_router.dart'
    show SessionCommunicationTopics;

part 'session_messaging_controller.g.dart';

/// Thin compatibility facade. Feature owners hold state and implement protocols.
@riverpod
class SessionMessagingController extends _$SessionMessagingController {
  @override
  void build(SessionController session) {}

  void handleDataReceived(SessionTransportPacket packet) => SessionPacketRouter(
    chat: session.chat.receive,
    reaction: session.reactions.receive,
    removal: session.keeper.moderation.receive,
    admission: session.admission.handleTransportEvent,
  ).handle(TransportPacketReceived(packet));

  Future<bool> sendMessage(String text, {String? recipientIdentity}) async =>
      await session.chat.send(text, recipientIdentity: recipientIdentity) ==
      ChatSendOutcome.sent;
  Future<void> sendReaction(String emoji) => session.reactions.send(emoji);
}
