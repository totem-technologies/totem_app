// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_prompt_schema.dart';

@immutable
final class SessionPromptsSchema {
  const SessionPromptsSchema({required this.prompts});

  factory SessionPromptsSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptsSchema(
      prompts: (json['prompts'] as List<dynamic>)
          .map((e) => SessionPromptSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<SessionPromptSchema> prompts;

  Map<String, dynamic> toJson() {
    return {'prompts': prompts.map((e) => e.toJson()).toList()};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('prompts');
  }

  SessionPromptsSchema copyWith({List<SessionPromptSchema>? prompts}) {
    return SessionPromptsSchema(prompts: prompts ?? this.prompts);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptsSchema && listEquals(prompts, other.prompts);
  }

  @override
  int get hashCode {
    return Object.hashAll(prompts).hashCode;
  }

  @override
  String toString() {
    return 'SessionPromptsSchema(prompts: $prompts)';
  }
}
