// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_detail_schema.dart';

@immutable
final class SessionConflictSchema {
  const SessionConflictSchema({
    required this.message,
    required this.conflictingSessions,
  });

  factory SessionConflictSchema.fromJson(Map<String, dynamic> json) {
    return SessionConflictSchema(
      message: json['message'] as String,
      conflictingSessions: (json['conflicting_sessions'] as List<dynamic>)
          .map((e) => SessionDetailSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String message;

  final List<SessionDetailSchema> conflictingSessions;

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'conflicting_sessions': conflictingSessions
          .map((e) => e.toJson())
          .toList(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('message') &&
        json['message'] is String &&
        json.containsKey('conflicting_sessions');
  }

  SessionConflictSchema copyWith({
    String? message,
    List<SessionDetailSchema>? conflictingSessions,
  }) {
    return SessionConflictSchema(
      message: message ?? this.message,
      conflictingSessions: conflictingSessions ?? this.conflictingSessions,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionConflictSchema &&
            message == other.message &&
            listEquals(conflictingSessions, other.conflictingSessions);
  }

  @override
  int get hashCode {
    return Object.hash(message, Object.hashAll(conflictingSessions));
  }

  @override
  String toString() {
    return 'SessionConflictSchema(message: $message, conflictingSessions: $conflictingSessions)';
  }
}
