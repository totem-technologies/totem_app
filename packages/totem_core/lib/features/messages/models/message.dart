import 'package:flutter/foundation.dart';

enum MessageStatus { pending, sent, failed }

@immutable
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.isOwn = false,
    this.status = MessageStatus.sent,
    this.clientMessageId,
    this.cursor,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isOwn;
  final MessageStatus status;
  final String? clientMessageId;

  /// Opaque server cursor used only for incremental message requests.
  final String? cursor;

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? text,
    DateTime? sentAt,
    bool? isOwn,
    MessageStatus? status,
    String? Function()? clientMessageId,
    String? Function()? cursor,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isOwn: isOwn ?? this.isOwn,
      status: status ?? this.status,
      clientMessageId: clientMessageId != null
          ? clientMessageId()
          : this.clientMessageId,
      cursor: cursor != null ? cursor() : this.cursor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Message && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
