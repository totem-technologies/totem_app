// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SessionMessageRecipientResultSchema {
  const SessionMessageRecipientResultSchema({
    required this.recipientSlug,
    required this.conversationId,
    required this.messageId,
  });

  factory SessionMessageRecipientResultSchema.fromJson(
    Map<String, dynamic> json,
  ) {
    return SessionMessageRecipientResultSchema(
      recipientSlug: json['recipient_slug'] as String,
      conversationId: json['conversation_id'] as String,
      messageId: json['message_id'] as String,
    );
  }

  final String recipientSlug;

  final String conversationId;

  final String messageId;

  Map<String, dynamic> toJson() {
    return {
      'recipient_slug': recipientSlug,
      'conversation_id': conversationId,
      'message_id': messageId,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('recipient_slug') &&
        json['recipient_slug'] is String &&
        json.containsKey('conversation_id') &&
        json['conversation_id'] is String &&
        json.containsKey('message_id') &&
        json['message_id'] is String;
  }

  SessionMessageRecipientResultSchema copyWith({
    String? recipientSlug,
    String? conversationId,
    String? messageId,
  }) {
    return SessionMessageRecipientResultSchema(
      recipientSlug: recipientSlug ?? this.recipientSlug,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionMessageRecipientResultSchema &&
            recipientSlug == other.recipientSlug &&
            conversationId == other.conversationId &&
            messageId == other.messageId;
  }

  @override
  int get hashCode {
    return Object.hash(recipientSlug, conversationId, messageId);
  }

  @override
  String toString() {
    return 'SessionMessageRecipientResultSchema(recipientSlug: $recipientSlug, conversationId: $conversationId, messageId: $messageId)';
  }
}
