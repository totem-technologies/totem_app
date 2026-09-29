// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SessionPromptSchema {
  const SessionPromptSchema({
    required this.prompt,
    this.id = const Omittable.absent(),
    this.position = const Omittable.absent(),
    this.roundNumber = const Omittable.absent(),
  });

  factory SessionPromptSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptSchema(
      id: json.containsKey('id')
          ? Omittable(json['id'] != null ? (json['id'] as num).toInt() : null)
          : const Omittable.absent(),
      prompt: json['prompt'] as String,
      position: json.containsKey('position')
          ? Omittable(
              json['position'] != null
                  ? (json['position'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
      roundNumber: json.containsKey('round_number')
          ? Omittable(
              json['round_number'] != null
                  ? (json['round_number'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
    );
  }

  final Omittable<int?> id;

  final String prompt;

  final Omittable<int?> position;

  final Omittable<int?> roundNumber;

  Map<String, dynamic> toJson() {
    return {
      if (id.isPresent) 'id': id.value,
      'prompt': prompt,
      if (position.isPresent) 'position': position.value,
      if (roundNumber.isPresent) 'round_number': roundNumber.value,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('prompt') && json['prompt'] is String;
  }

  SessionPromptSchema copyWith({
    Omittable<int?>? id,
    String? prompt,
    Omittable<int?>? position,
    Omittable<int?>? roundNumber,
  }) {
    return SessionPromptSchema(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      position: position ?? this.position,
      roundNumber: roundNumber ?? this.roundNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptSchema &&
            id == other.id &&
            prompt == other.prompt &&
            position == other.position &&
            roundNumber == other.roundNumber;
  }

  @override
  int get hashCode {
    return Object.hash(id, prompt, position, roundNumber);
  }

  @override
  String toString() {
    return 'SessionPromptSchema(id: $id, prompt: $prompt, position: $position, roundNumber: $roundNumber)';
  }
}
