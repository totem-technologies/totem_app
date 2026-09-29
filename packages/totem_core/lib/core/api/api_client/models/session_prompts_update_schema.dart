// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_prompt_update_schema.dart';

@immutable
final class SessionPromptsUpdateSchema {
  const SessionPromptsUpdateSchema({required this.prompts});

  factory SessionPromptsUpdateSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptsUpdateSchema(
      prompts: (json['prompts'] as List<dynamic>)
          .map(
            (e) =>
                SessionPromptUpdateSchema.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final List<SessionPromptUpdateSchema> prompts;

  Map<String, dynamic> toJson() {
    return {'prompts': prompts.map((e) => e.toJson()).toList()};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('prompts');
  }

  SessionPromptsUpdateSchema copyWith({
    List<SessionPromptUpdateSchema>? prompts,
  }) {
    return SessionPromptsUpdateSchema(prompts: prompts ?? this.prompts);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptsUpdateSchema &&
            listEquals(prompts, other.prompts);
  }

  @override
  int get hashCode {
    return Object.hashAll(prompts).hashCode;
  }

  @override
  String toString() {
    return 'SessionPromptsUpdateSchema(prompts: $prompts)';
  }
}
