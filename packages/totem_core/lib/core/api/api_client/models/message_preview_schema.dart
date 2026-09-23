// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class MessagePreviewSchema {
  const MessagePreviewSchema({
    required this.id,
    required this.senderSlug,
    required this.text,
    required this.createdAt,
    required this.isMine,
    required this.isDeleted,
  });

  factory MessagePreviewSchema.fromJson(Map<String, dynamic> json) {
    return MessagePreviewSchema(
      id: json['id'] as String,
      senderSlug: json['sender_slug'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool,
      isDeleted: json['is_deleted'] as bool,
    );
  }

  final String id;

  final String senderSlug;

  final String text;

  final DateTime createdAt;

  final bool isMine;

  final bool isDeleted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_slug': senderSlug,
      'text': text,
      'created_at': createdAt.toIso8601String(),
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
        json.containsKey('created_at') &&
        json['created_at'] is String &&
        json.containsKey('is_mine') &&
        json['is_mine'] is bool &&
        json.containsKey('is_deleted') &&
        json['is_deleted'] is bool;
  }

  MessagePreviewSchema copyWith({
    String? id,
    String? senderSlug,
    String? text,
    DateTime? createdAt,
    bool? isMine,
    bool? isDeleted,
  }) {
    return MessagePreviewSchema(
      id: id ?? this.id,
      senderSlug: senderSlug ?? this.senderSlug,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MessagePreviewSchema &&
            id == other.id &&
            senderSlug == other.senderSlug &&
            text == other.text &&
            createdAt == other.createdAt &&
            isMine == other.isMine &&
            isDeleted == other.isDeleted;
  }

  @override
  int get hashCode {
    return Object.hash(id, senderSlug, text, createdAt, isMine, isDeleted);
  }

  @override
  String toString() {
    return 'MessagePreviewSchema(id: $id, senderSlug: $senderSlug, text: $text, createdAt: $createdAt, isMine: $isMine, isDeleted: $isDeleted)';
  }
}
