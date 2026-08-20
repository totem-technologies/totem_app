// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class ResolveConflictsSchema {
  const ResolveConflictsSchema({required this.conflictingSessionSlugs});

  factory ResolveConflictsSchema.fromJson(Map<String, dynamic> json) {
    return ResolveConflictsSchema(
      conflictingSessionSlugs:
          (json['conflicting_session_slugs'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
    );
  }

  final List<String> conflictingSessionSlugs;

  Map<String, dynamic> toJson() {
    return {
      'conflicting_session_slugs': conflictingSessionSlugs,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('conflicting_session_slugs');
  }

  ResolveConflictsSchema copyWith({List<String>? conflictingSessionSlugs}) {
    return ResolveConflictsSchema(
      conflictingSessionSlugs:
          conflictingSessionSlugs ?? this.conflictingSessionSlugs,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ResolveConflictsSchema &&
            listEquals(conflictingSessionSlugs, other.conflictingSessionSlugs);
  }

  @override
  int get hashCode {
    return Object.hashAll(conflictingSessionSlugs).hashCode;
  }

  @override
  String toString() {
    return 'ResolveConflictsSchema(conflictingSessionSlugs: $conflictingSessionSlugs)';
  }
}
