import 'package:flutter/foundation.dart';
import 'package:totem_core/core/api/api_client/models/public_user_schema.dart';
import 'package:totem_core/features/messages/models/message.dart';

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.peer,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final PublicUserSchema peer;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  Conversation copyWith({
    String? id,
    PublicUserSchema? peer,
    Message? Function()? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      peer: peer ?? this.peer,
      lastMessage: lastMessage != null ? lastMessage() : this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Conversation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
