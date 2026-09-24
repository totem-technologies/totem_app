// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:totem_core/core/api/api_client/api_client.dart';

@immutable
final class StartRoomEvent {
  const StartRoomEvent({this.type, this.prompt = const Omittable.absent()});

  factory StartRoomEvent.fromJson(Map<String, dynamic> json) {
    return StartRoomEvent(
      type: json['type'] as String?,
      prompt: json.containsKey('prompt')
          ? Omittable(json['prompt'] as String?)
          : const Omittable.absent(),
    );
  }

  final String? type;

  final Omittable<String?> prompt;

  /// The value with the schema default applied when absent.
  String get typeOrDefault {
    return type ?? 'start_room';
  }

  Map<String, dynamic> toJson() {
    return {'type': ?type, if (prompt.isPresent) 'prompt': prompt.value};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.keys.any((key) => const {'type', 'prompt'}.contains(key));
  }

  StartRoomEvent copyWith({
    String? Function()? type,
    Omittable<String?>? prompt,
  }) {
    return StartRoomEvent(
      type: type != null ? type() : this.type,
      prompt: prompt ?? this.prompt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StartRoomEvent && type == other.type && prompt == other.prompt;
  }

  @override
  int get hashCode {
    return Object.hash(type, prompt);
  }

  @override
  String toString() {
    return 'StartRoomEvent(type: $type, prompt: $prompt)';
  }
}
