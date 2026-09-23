// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_participant_schema.dart';

@immutable
final class SessionParticipantPageSchema {
  const SessionParticipantPageSchema({
    required this.items,
    required this.nextCursor,
  });

  factory SessionParticipantPageSchema.fromJson(Map<String, dynamic> json) {
    return SessionParticipantPageSchema(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => SessionParticipantSchema.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<SessionParticipantSchema> items;

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

  SessionParticipantPageSchema copyWith({
    List<SessionParticipantSchema>? items,
    String? Function()? nextCursor,
  }) {
    return SessionParticipantPageSchema(
      items: items ?? this.items,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionParticipantPageSchema &&
            listEquals(items, other.items) &&
            nextCursor == other.nextCursor;
  }

  @override
  int get hashCode {
    return Object.hash(Object.hashAll(items), nextCursor);
  }

  @override
  String toString() {
    return 'SessionParticipantPageSchema(items: $items, nextCursor: $nextCursor)';
  }
}
