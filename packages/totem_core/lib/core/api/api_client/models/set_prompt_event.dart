// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

/// Keeper sets or replaces the active round prompt during a live session.
@immutable
final class SetPromptEvent {
  const SetPromptEvent({
    required this.prompt,
    this.type = 'set_prompt',
  });

  factory SetPromptEvent.fromJson(Map<String, dynamic> json) {
    return SetPromptEvent(
      type: json.containsKey('type') ? json['type'] as String : 'set_prompt',
      prompt: json['prompt'] as String,
    );
  }

  final String type;

  final String prompt;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'prompt': prompt,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('prompt') && json['prompt'] is String;
  }

  SetPromptEvent copyWith({
    String Function()? type,
    String? prompt,
  }) {
    return SetPromptEvent(
      type: type != null ? type() : this.type,
      prompt: prompt ?? this.prompt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SetPromptEvent && type == other.type && prompt == other.prompt;
  }

  @override
  int get hashCode {
    return Object.hash(type, prompt);
  }

  @override
  String toString() {
    return 'SetPromptEvent(type: $type, prompt: $prompt)';
  }
}
