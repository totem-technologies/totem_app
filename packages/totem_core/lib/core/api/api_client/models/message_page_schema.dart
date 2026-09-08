// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'message_schema.dart';

/// Initial and before pages are newest-first; after pages are oldest-first.
@immutable
final class MessagePageSchema {
  const MessagePageSchema({
    required this.items,
    required this.nextBefore,
    required this.nextAfter,
    required this.hasMore,
  });

  factory MessagePageSchema.fromJson(Map<String, dynamic> json) {
    return MessagePageSchema(
      items: (json['items'] as List<dynamic>)
          .map((e) => MessageSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextBefore: json['next_before'] as String?,
      nextAfter: json['next_after'] as String?,
      hasMore: json['has_more'] as bool,
    );
  }

  final List<MessageSchema> items;

  final String? nextBefore;

  final String? nextAfter;

  final bool hasMore;

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'next_before': ?nextBefore,
      'next_after': ?nextAfter,
      'has_more': hasMore,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('items') &&
        json.containsKey('next_before') &&
        json['next_before'] is String &&
        json.containsKey('next_after') &&
        json['next_after'] is String &&
        json.containsKey('has_more') &&
        json['has_more'] is bool;
  }

  MessagePageSchema copyWith({
    List<MessageSchema>? items,
    String? Function()? nextBefore,
    String? Function()? nextAfter,
    bool? hasMore,
  }) {
    return MessagePageSchema(
      items: items ?? this.items,
      nextBefore: nextBefore != null ? nextBefore() : this.nextBefore,
      nextAfter: nextAfter != null ? nextAfter() : this.nextAfter,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MessagePageSchema &&
            listEquals(items, other.items) &&
            nextBefore == other.nextBefore &&
            nextAfter == other.nextAfter &&
            hasMore == other.hasMore;
  }

  @override
  int get hashCode {
    return Object.hash(Object.hashAll(items), nextBefore, nextAfter, hasMore);
  }

  @override
  String toString() {
    return 'MessagePageSchema(items: $items, nextBefore: $nextBefore, nextAfter: $nextAfter, hasMore: $hasMore)';
  }
}
