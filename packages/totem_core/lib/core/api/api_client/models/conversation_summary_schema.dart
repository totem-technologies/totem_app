// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'message_peer_schema.dart';
import 'message_preview_schema.dart';

@immutable
final class ConversationSummarySchema {
  const ConversationSummarySchema({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ConversationSummarySchema.fromJson(Map<String, dynamic> json) {
    return ConversationSummarySchema(
      id: json['id'] as String,
      peer: MessagePeerSchema.fromJson(json['peer'] as Map<String, dynamic>),
      lastMessage: json['last_message'] != null
          ? MessagePreviewSchema.fromJson(
              json['last_message'] as Map<String, dynamic>,
            )
          : null,
      unreadCount: (json['unread_count'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;

  final MessagePeerSchema peer;

  final MessagePreviewSchema? lastMessage;

  final int unreadCount;

  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peer': peer.toJson(),
      if (lastMessage != null) 'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('id') &&
        json['id'] is String &&
        json.containsKey('peer') &&
        json.containsKey('last_message') &&
        json.containsKey('unread_count') &&
        json['unread_count'] is num &&
        json.containsKey('updated_at') &&
        json['updated_at'] is String;
  }

  ConversationSummarySchema copyWith({
    String? id,
    MessagePeerSchema? peer,
    MessagePreviewSchema? Function()? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return ConversationSummarySchema(
      id: id ?? this.id,
      peer: peer ?? this.peer,
      lastMessage: lastMessage != null ? lastMessage() : this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationSummarySchema &&
            id == other.id &&
            peer == other.peer &&
            lastMessage == other.lastMessage &&
            unreadCount == other.unreadCount &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, peer, lastMessage, unreadCount, updatedAt);
  }

  @override
  String toString() {
    return 'ConversationSummarySchema(id: $id, peer: $peer, lastMessage: $lastMessage, unreadCount: $unreadCount, updatedAt: $updatedAt)';
  }
}
