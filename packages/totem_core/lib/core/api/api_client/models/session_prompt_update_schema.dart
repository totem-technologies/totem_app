// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SessionPromptUpdateSchema {
  const SessionPromptUpdateSchema({
    required this.prompt,
    this.id = const Omittable.absent(),
  });

  factory SessionPromptUpdateSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptUpdateSchema(
      id: json.containsKey('id')
          ? Omittable(json['id'] != null ? (json['id'] as num).toInt() : null)
          : const Omittable.absent(),
      prompt: json['prompt'] as String,
    );
  }

  final Omittable<int?> id;

  final String prompt;

  Map<String, dynamic> toJson() {
    return {if (id.isPresent) 'id': id.value, 'prompt': prompt};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('prompt') && json['prompt'] is String;
  }

  SessionPromptUpdateSchema copyWith({Omittable<int?>? id, String? prompt}) {
    return SessionPromptUpdateSchema(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptUpdateSchema &&
            id == other.id &&
            prompt == other.prompt;
  }

  @override
  int get hashCode {
    return Object.hash(id, prompt);
  }

  @override
  String toString() {
    return 'SessionPromptUpdateSchema(id: $id, prompt: $prompt)';
  }
}
