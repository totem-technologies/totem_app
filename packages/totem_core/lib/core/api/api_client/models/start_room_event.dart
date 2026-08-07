// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class StartRoomEvent {
  const StartRoomEvent({
    this.type = 'start_room',
    this.prompt,
  });

  factory StartRoomEvent.fromJson(Map<String, dynamic> json) {
    return StartRoomEvent(
      type: json.containsKey('type') ? json['type'] as String : 'start_room',
      prompt: json['prompt'] as String?,
    );
  }

  final String type;

  final String? prompt;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'prompt': ?prompt,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.keys.any((key) => const {'type', 'prompt'}.contains(key));
  }

  StartRoomEvent copyWith({
    String Function()? type,
    String? Function()? prompt,
  }) {
    return StartRoomEvent(
      type: type != null ? type() : this.type,
      prompt: prompt != null ? prompt() : this.prompt,
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
