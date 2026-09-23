// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class MessageSchema {
  const MessageSchema({
    required this.id,
    required this.senderSlug,
    required this.text,
    required this.clientMessageId,
    required this.createdAt,
    required this.cursor,
    required this.isMine,
    required this.isDeleted,
  });

  factory MessageSchema.fromJson(Map<String, dynamic> json) {
    return MessageSchema(
      id: json['id'] as String,
      senderSlug: json['sender_slug'] as String,
      text: json['text'] as String,
      clientMessageId: json['client_message_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      cursor: json['cursor'] as String,
      isMine: json['is_mine'] as bool,
      isDeleted: json['is_deleted'] as bool,
    );
  }

  final String id;

  final String senderSlug;

  final String text;

  final String? clientMessageId;

  final DateTime createdAt;

  final String cursor;

  final bool isMine;

  final bool isDeleted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_slug': senderSlug,
      'text': text,
      'client_message_id': ?clientMessageId,
      'created_at': createdAt.toIso8601String(),
      'cursor': cursor,
      'is_mine': isMine,
      'is_deleted': isDeleted,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('id') &&
        json['id'] is String &&
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
        json['is_mine'] is bool &&
        json.containsKey('is_deleted') &&
        json['is_deleted'] is bool;
  }

  MessageSchema copyWith({
    String? id,
    String? senderSlug,
    String? text,
    String? Function()? clientMessageId,
    DateTime? createdAt,
    String? cursor,
    bool? isMine,
    bool? isDeleted,
  }) {
    return MessageSchema(
      id: id ?? this.id,
      senderSlug: senderSlug ?? this.senderSlug,
      text: text ?? this.text,
      clientMessageId: clientMessageId != null
          ? clientMessageId()
          : this.clientMessageId,
      createdAt: createdAt ?? this.createdAt,
      cursor: cursor ?? this.cursor,
      isMine: isMine ?? this.isMine,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MessageSchema &&
            id == other.id &&
            senderSlug == other.senderSlug &&
            text == other.text &&
            clientMessageId == other.clientMessageId &&
            createdAt == other.createdAt &&
            cursor == other.cursor &&
            isMine == other.isMine &&
            isDeleted == other.isDeleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      senderSlug,
      text,
      clientMessageId,
      createdAt,
      cursor,
      isMine,
      isDeleted,
    );
  }

  @override
  String toString() {
    return 'MessageSchema(id: $id, senderSlug: $senderSlug, text: $text, clientMessageId: $clientMessageId, createdAt: $createdAt, cursor: $cursor, isMine: $isMine, isDeleted: $isDeleted)';
  }
}
