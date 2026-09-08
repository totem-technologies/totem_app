// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class MessageSchema {
  const MessageSchema({
    required this.id,
    required this.senderId,
    required this.senderSlug,
    required this.text,
    required this.clientMessageId,
    required this.createdAt,
    required this.cursor,
    required this.isMine,
  });

  factory MessageSchema.fromJson(Map<String, dynamic> json) {
    return MessageSchema(
      id: json['id'] as String,
      senderId: (json['sender_id'] as num).toInt(),
      senderSlug: json['sender_slug'] as String,
      text: json['text'] as String,
      clientMessageId: json['client_message_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      cursor: json['cursor'] as String,
      isMine: json['is_mine'] as bool,
    );
  }

  final String id;

  final int senderId;

  final String senderSlug;

  final String text;

  final String? clientMessageId;

  final DateTime createdAt;

  final String cursor;

  final bool isMine;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_slug': senderSlug,
      'text': text,
      'client_message_id': ?clientMessageId,
      'created_at': createdAt.toIso8601String(),
      'cursor': cursor,
      'is_mine': isMine,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('id') &&
        json['id'] is String &&
        json.containsKey('sender_id') &&
        json['sender_id'] is num &&
        json.containsKey('sender_slug') &&
        json['sender_slug'] is String &&
        json.containsKey('text') &&
        json['text'] is String &&
        json.containsKey('client_message_id') &&
        json['client_message_id'] is String &&
        json.containsKey('created_at') &&
        json['created_at'] is String &&
        json.containsKey('cursor') &&
        json['cursor'] is String &&
        json.containsKey('is_mine') &&
        json['is_mine'] is bool;
  }

  MessageSchema copyWith({
    String? id,
    int? senderId,
    String? senderSlug,
    String? text,
    String? Function()? clientMessageId,
    DateTime? createdAt,
    String? cursor,
    bool? isMine,
  }) {
    return MessageSchema(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderSlug: senderSlug ?? this.senderSlug,
      text: text ?? this.text,
      clientMessageId: clientMessageId != null
          ? clientMessageId()
          : this.clientMessageId,
      createdAt: createdAt ?? this.createdAt,
      cursor: cursor ?? this.cursor,
      isMine: isMine ?? this.isMine,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MessageSchema &&
            id == other.id &&
            senderId == other.senderId &&
            senderSlug == other.senderSlug &&
            text == other.text &&
            clientMessageId == other.clientMessageId &&
            createdAt == other.createdAt &&
            cursor == other.cursor &&
            isMine == other.isMine;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      senderId,
      senderSlug,
      text,
      clientMessageId,
      createdAt,
      cursor,
      isMine,
    );
  }

  @override
  String toString() {
    return 'MessageSchema(id: $id, senderId: $senderId, senderSlug: $senderSlug, text: $text, clientMessageId: $clientMessageId, createdAt: $createdAt, cursor: $cursor, isMine: $isMine)';
  }
}
