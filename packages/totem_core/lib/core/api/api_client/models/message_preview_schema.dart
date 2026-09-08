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
  });

  factory MessagePreviewSchema.fromJson(Map<String, dynamic> json) {
    return MessagePreviewSchema(
      id: json['id'] as String,
      senderSlug: json['sender_slug'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool,
    );
  }

  final String id;

  final String senderSlug;

  final String text;

  final DateTime createdAt;

  final bool isMine;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_slug': senderSlug,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'is_mine': isMine,
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
        json['is_mine'] is bool;
  }

  MessagePreviewSchema copyWith({
    String? id,
    String? senderSlug,
    String? text,
    DateTime? createdAt,
    bool? isMine,
  }) {
    return MessagePreviewSchema(
      id: id ?? this.id,
      senderSlug: senderSlug ?? this.senderSlug,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
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
            isMine == other.isMine;
  }

  @override
  int get hashCode {
    return Object.hash(id, senderSlug, text, createdAt, isMine);
  }

  @override
  String toString() {
    return 'MessagePreviewSchema(id: $id, senderSlug: $senderSlug, text: $text, createdAt: $createdAt, isMine: $isMine)';
  }
}
