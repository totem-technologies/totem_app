// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SessionPromptSchema {
  const SessionPromptSchema({
    required this.id,
    required this.prompt,
    required this.position,
    required this.consumedRoundNumber,
  });

  factory SessionPromptSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptSchema(
      id: (json['id'] as num).toInt(),
      prompt: json['prompt'] as String,
      position: json['position'] != null
          ? (json['position'] as num).toInt()
          : null,
      consumedRoundNumber: json['consumed_round_number'] != null
          ? (json['consumed_round_number'] as num).toInt()
          : null,
    );
  }

  final int id;

  final String prompt;

  final int? position;

  final int? consumedRoundNumber;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'position': position,
      'consumed_round_number': consumedRoundNumber,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('id') &&
        json['id'] is num &&
        json.containsKey('prompt') &&
        json['prompt'] is String &&
        json.containsKey('position') &&
        (json['position'] == null || json['position'] is num) &&
        json.containsKey('consumed_round_number') &&
        (json['consumed_round_number'] == null ||
            json['consumed_round_number'] is num);
  }

  SessionPromptSchema copyWith({
    int? id,
    String? prompt,
    int? Function()? position,
    int? Function()? consumedRoundNumber,
  }) {
    return SessionPromptSchema(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      position: position != null ? position() : this.position,
      consumedRoundNumber: consumedRoundNumber != null
          ? consumedRoundNumber()
          : this.consumedRoundNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptSchema &&
            id == other.id &&
            prompt == other.prompt &&
            position == other.position &&
            consumedRoundNumber == other.consumedRoundNumber;
  }

  @override
  int get hashCode {
    return Object.hash(id, prompt, position, consumedRoundNumber);
  }

  @override
  String toString() {
    return 'SessionPromptSchema(id: $id, prompt: $prompt, position: $position, consumedRoundNumber: $consumedRoundNumber)';
  }
}
