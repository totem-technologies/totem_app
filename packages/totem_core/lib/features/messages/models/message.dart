import 'package:flutter/foundation.dart';

enum MessageStatus { sent, delivered, read }

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
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isOwn;
  final MessageStatus status;

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? text,
    DateTime? sentAt,
    bool? isOwn,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isOwn: isOwn ?? this.isOwn,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Message && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
