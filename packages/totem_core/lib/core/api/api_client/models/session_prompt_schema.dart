// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SessionPromptSchema {
  const SessionPromptSchema({
    required this.id,
    required this.prompt,
    required this.position,
    required this.consumedRoundNumbers,
  });

  factory SessionPromptSchema.fromJson(Map<String, dynamic> json) {
    return SessionPromptSchema(
      id: (json['id'] as num).toInt(),
      prompt: json['prompt'] as String,
      position: json['position'] != null
          ? (json['position'] as num).toInt()
          : null,
      consumedRoundNumbers: (json['consumed_round_numbers'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }

  final int id;

  final String prompt;

  final int? position;

  final List<int> consumedRoundNumbers;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'position': position,
      'consumed_round_numbers': consumedRoundNumbers,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('id') &&
        json['id'] is num &&
        json.containsKey('prompt') &&
        json['prompt'] is String &&
        json.containsKey('position') &&
        (json['position'] == null || json['position'] is num) &&
        json.containsKey('consumed_round_numbers');
  }

  SessionPromptSchema copyWith({
    int? id,
    String? prompt,
    int? Function()? position,
    List<int>? consumedRoundNumbers,
  }) {
    return SessionPromptSchema(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      position: position != null ? position() : this.position,
      consumedRoundNumbers: consumedRoundNumbers ?? this.consumedRoundNumbers,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptSchema &&
            id == other.id &&
            prompt == other.prompt &&
            position == other.position &&
            listEquals(consumedRoundNumbers, other.consumedRoundNumbers);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      prompt,
      position,
      Object.hashAll(consumedRoundNumbers),
    );
  }

  @override
  String toString() {
    return 'SessionPromptSchema(id: $id, prompt: $prompt, position: $position, consumedRoundNumbers: $consumedRoundNumbers)';
  }
}
