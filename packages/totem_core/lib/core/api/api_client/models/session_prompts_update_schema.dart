// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_prompt_update_schema.dart';

@immutable
final class SessionPromptsUpdateSchema {
  const SessionPromptsUpdateSchema({
    required this.expectedRevision,
    required this.prompts,
  });

  factory SessionPromptsUpdateSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptsUpdateSchema(
      expectedRevision: (json['expected_revision'] as num).toInt(),
      prompts: (json['prompts'] as List<dynamic>)
          .map(
            (e) =>
                SessionPromptUpdateSchema.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final int expectedRevision;

  final List<SessionPromptUpdateSchema> prompts;

  Map<String, dynamic> toJson() {
    return {
      'expected_revision': expectedRevision,
      'prompts': prompts.map((e) => e.toJson()).toList(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('expected_revision') &&
        json['expected_revision'] is num &&
        json.containsKey('prompts');
  }

  SessionPromptsUpdateSchema copyWith({
    int? expectedRevision,
    List<SessionPromptUpdateSchema>? prompts,
  }) {
    return SessionPromptsUpdateSchema(
      expectedRevision: expectedRevision ?? this.expectedRevision,
      prompts: prompts ?? this.prompts,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptsUpdateSchema &&
            expectedRevision == other.expectedRevision &&
            listEquals(prompts, other.prompts);
  }

  @override
  int get hashCode {
    return Object.hash(expectedRevision, Object.hashAll(prompts));
  }

  @override
  String toString() {
    return 'SessionPromptsUpdateSchema(expectedRevision: $expectedRevision, prompts: $prompts)';
  }
}
