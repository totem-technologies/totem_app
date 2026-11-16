import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:totem_core/features/sessions/models/session_chat_message.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import 'package:uuid/uuid.dart';

export 'package:totem_core/features/sessions/models/session_chat_message.dart';

enum ChatSendOutcome {
  sent,
  unauthorized,
  invalidRecipient,
  disconnected,
  invalidMessage,
  failed,
}

/// Session-local chat authority; panel selection and unread state are UI state.
class SessionChatService extends ChangeNotifier {
  SessionChatService({
    required this.transport,
    required this.keeperIdentity,
    required this.isKeeper,
    DateTime Function()? now,
    String Function()? createId,
  }) : _now = now ?? DateTime.now,
       _createId = createId ?? const Uuid().v4;

  final SessionTransport? Function() transport;
  final String Function() keeperIdentity;
  final bool Function() isKeeper;
  final DateTime Function() _now;
  final String Function() _createId;
  final Set<String> _ids = {};
  List<SessionChatMessage> _messages = const [];
  List<SessionChatMessage> get messages => _messages;
  Object? lastError;
  bool _disposed = false;
  int _generation = 0;

  void add(SessionChatMessage message) {
    if (_disposed || !_ids.add(message.id)) return;
    // Preserve reliable arrival order. Peer timestamps are display data, not
    // authority to reorder history or unread-message arrivals.
    _messages = List.unmodifiable([..._messages, message]);
    notifyListeners();
  }

  void receive(SessionTransportPacket packet) {
    if (_disposed || packet.topic != SessionCommunicationTopics.chat.topic) {
      return;
    }
    try {
      final map = jsonDecode(utf8.decode(packet.bytes)) as Map<String, dynamic>;
      final message = SessionChatMessage.fromMap(map, packet.sender);
      if (message.id.isEmpty || message.message.trim().isEmpty) return;
      final sender = packet.sender?.identity;
      final keeper = keeperIdentity();
      final local = transport()?.localIdentity;
      if (sender == null || keeper.isEmpty) return;
      if (message.isEveryoneThread) {
        if (sender != keeper) return;
      } else {
        final recipient = message.recipientIdentity;
        final fromKeeper =
            sender == keeper && recipient == local && local != keeper;
        final toKeeper =
            local == keeper && recipient == local && sender != keeper;
        if (local == null || (!fromKeeper && !toKeeper)) return;
      }
      add(message);
    } catch (error) {
      lastError = error;
    }
  }

  Future<ChatSendOutcome> send(String text, {String? recipientIdentity}) async {
    final connection = transport();
    if (_disposed ||
        connection == null ||
        connection.localIdentity == null ||
        connection.connectionState !=
            SessionTransportConnectionState.connected) {
      return ChatSendOutcome.disconnected;
    }
    if (text.trim().isEmpty) return ChatSendOutcome.invalidMessage;
    final recipient = recipientIdentity == null || recipientIdentity.isEmpty
        ? null
        : recipientIdentity;
    final local = connection.localIdentity!;
    if (recipient == null) {
      if (!isKeeper()) return ChatSendOutcome.unauthorized;
    } else {
      if (recipient == local ||
          (!isKeeper() && recipient != keeperIdentity()) ||
          !connection.participants.any(
            (participant) =>
                participant.identity == recipient && !participant.isLocal,
          )) {
        return ChatSendOutcome.invalidRecipient;
      }
    }
    final generation = _generation;
    final message = SessionChatMessage(
      message: text,
      timestamp: _now().millisecondsSinceEpoch,
      id: _createId(),
      sender: true,
      participant: connection.participants
          .where((p) => p.identity == local)
          .firstOrNull,
      recipientIdentity: recipient,
    );
    try {
      await connection
          .publish(
            SessionTransportPacket(
              bytes: utf8.encode(message.toJson()),
              topic: SessionCommunicationTopics.chat.topic,
              reliable: true,
              recipients: recipient == null ? const [] : [recipient],
            ),
          )
          .timeout(const Duration(seconds: 5));
      if (_disposed ||
          generation != _generation ||
          !identical(transport(), connection)) {
        return ChatSendOutcome.disconnected;
      }
      lastError = null;
      add(message);
      return ChatSendOutcome.sent;
    } catch (error) {
      if (!_disposed && generation == _generation) lastError = error;
      return ChatSendOutcome.failed;
    }
  }

  void cancelPending() {
    _generation++;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelPending();
    super.dispose();
  }
}
