// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_prompt_schema.dart';

@immutable
final class SessionPromptsSchema {
  const SessionPromptsSchema({required this.revision, required this.prompts});

  factory SessionPromptsSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptsSchema(
      revision: (json['revision'] as num).toInt(),
      prompts: (json['prompts'] as List<dynamic>)
          .map((e) => SessionPromptSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int revision;

  final List<SessionPromptSchema> prompts;

  Map<String, dynamic> toJson() {
    return {
      'revision': revision,
      'prompts': prompts.map((e) => e.toJson()).toList(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('revision') &&
        json['revision'] is num &&
        json.containsKey('prompts');
  }

  SessionPromptsSchema copyWith({
    int? revision,
    List<SessionPromptSchema>? prompts,
  }) {
    return SessionPromptsSchema(
      revision: revision ?? this.revision,
      prompts: prompts ?? this.prompts,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptsSchema &&
            revision == other.revision &&
            listEquals(prompts, other.prompts);
  }

  @override
  int get hashCode {
    return Object.hash(revision, Object.hashAll(prompts));
  }

  @override
  String toString() {
    return 'SessionPromptsSchema(revision: $revision, prompts: $prompts)';
  }
}
