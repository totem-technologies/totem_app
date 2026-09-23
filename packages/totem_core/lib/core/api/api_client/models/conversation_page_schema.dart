// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'conversation_summary_schema.dart';

@immutable
final class ConversationPageSchema {
  const ConversationPageSchema({
    required this.items,
    required this.nextCursor,
    required this.totalUnreadCount,
  });

  factory ConversationPageSchema.fromJson(Map<String, dynamic> json) {
    return ConversationPageSchema(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) =>
                ConversationSummarySchema.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: json['next_cursor'] as String?,
      totalUnreadCount: (json['total_unread_count'] as num).toInt(),
    );
  }

  final List<ConversationSummarySchema> items;

  final String? nextCursor;

  final int totalUnreadCount;

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'next_cursor': ?nextCursor,
      'total_unread_count': totalUnreadCount,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('items') &&
        json.containsKey('next_cursor') &&
        json['next_cursor'] is String &&
        json.containsKey('total_unread_count') &&
        json['total_unread_count'] is num;
  }

  ConversationPageSchema copyWith({
    List<ConversationSummarySchema>? items,
    String? Function()? nextCursor,
    int? totalUnreadCount,
  }) {
    return ConversationPageSchema(
      items: items ?? this.items,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationPageSchema &&
            listEquals(items, other.items) &&
            nextCursor == other.nextCursor &&
            totalUnreadCount == other.totalUnreadCount;
  }

  @override
  int get hashCode {
    return Object.hash(Object.hashAll(items), nextCursor, totalUnreadCount);
  }

  @override
  String toString() {
    return 'ConversationPageSchema(items: $items, nextCursor: $nextCursor, totalUnreadCount: $totalUnreadCount)';
  }
}
