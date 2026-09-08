// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'conversation_summary_schema.dart';

@immutable
final class ConversationPageSchema {
  const ConversationPageSchema({required this.items, required this.nextCursor});

  factory ConversationPageSchema.fromJson(Map<String, dynamic> json) {
    return ConversationPageSchema(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) =>
                ConversationSummarySchema.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<ConversationSummarySchema> items;

  final String? nextCursor;

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'next_cursor': ?nextCursor,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('items') &&
        json.containsKey('next_cursor') &&
        json['next_cursor'] is String;
  }

  ConversationPageSchema copyWith({
    List<ConversationSummarySchema>? items,
    String? Function()? nextCursor,
  }) {
    return ConversationPageSchema(
      items: items ?? this.items,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationPageSchema &&
            listEquals(items, other.items) &&
            nextCursor == other.nextCursor;
  }

  @override
  int get hashCode {
    return Object.hash(Object.hashAll(items), nextCursor);
  }

  @override
  String toString() {
    return 'ConversationPageSchema(items: $items, nextCursor: $nextCursor)';
  }
}
