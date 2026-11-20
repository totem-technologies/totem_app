// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class BatchCommandInput {
  const BatchCommandInput({
    required this.commandId,
    required this.expectedRoomVersion,
  });

  factory BatchCommandInput.fromJson(Map<String, dynamic> json) {
    return BatchCommandInput(
      commandId: json['command_id'] as String,
      expectedRoomVersion: (json['expected_room_version'] as num).toInt(),
    );
  }

  final String commandId;

  final int expectedRoomVersion;

  Map<String, dynamic> toJson() {
    return {
      'command_id': commandId,
      'expected_room_version': expectedRoomVersion,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('command_id') &&
        json['command_id'] is String &&
        json.containsKey('expected_room_version') &&
        json['expected_room_version'] is num;
  }

  BatchCommandInput copyWith({String? commandId, int? expectedRoomVersion}) {
    return BatchCommandInput(
      commandId: commandId ?? this.commandId,
      expectedRoomVersion: expectedRoomVersion ?? this.expectedRoomVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BatchCommandInput &&
            commandId == other.commandId &&
            expectedRoomVersion == other.expectedRoomVersion;
  }

  @override
  int get hashCode {
    return Object.hash(commandId, expectedRoomVersion);
  }

  @override
  String toString() {
    return 'BatchCommandInput(commandId: $commandId, expectedRoomVersion: $expectedRoomVersion)';
  }
}
