// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class PassStickEvent {
  const PassStickEvent({
    this.type,
    this.prompt = const Omittable.absent(),
    this.sessionPromptId = const Omittable.absent(),
  });

  factory PassStickEvent.fromJson(Map<String, dynamic> json) {
    return PassStickEvent(
      type: json['type'] as String?,
      prompt: json.containsKey('prompt')
          ? Omittable(json['prompt'] as String?)
          : const Omittable.absent(),
      sessionPromptId: json.containsKey('session_prompt_id')
          ? Omittable(
              json['session_prompt_id'] != null
                  ? (json['session_prompt_id'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
    );
  }

  final String? type;

  final Omittable<String?> prompt;

  final Omittable<int?> sessionPromptId;

  /// The value with the schema default applied when absent.
  String get typeOrDefault {
    return type ?? 'pass_stick';
  }

  Map<String, dynamic> toJson() {
    return {
      'type': ?type,
      if (prompt.isPresent) 'prompt': prompt.value,
      if (sessionPromptId.isPresent) 'session_prompt_id': sessionPromptId.value,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.keys.any(
      (key) => const {'type', 'prompt', 'session_prompt_id'}.contains(key),
    );
  }

  PassStickEvent copyWith({
    String? Function()? type,
    Omittable<String?>? prompt,
    Omittable<int?>? sessionPromptId,
  }) {
    return PassStickEvent(
      type: type != null ? type() : this.type,
      prompt: prompt ?? this.prompt,
      sessionPromptId: sessionPromptId ?? this.sessionPromptId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PassStickEvent &&
            type == other.type &&
            prompt == other.prompt &&
            sessionPromptId == other.sessionPromptId;
  }

  @override
  int get hashCode {
    return Object.hash(type, prompt, sessionPromptId);
  }

  @override
  String toString() {
    return 'PassStickEvent(type: $type, prompt: $prompt, sessionPromptId: $sessionPromptId)';
  }
}
