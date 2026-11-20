// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class MembershipCommandInput {
  const MembershipCommandInput({
    required this.commandId,
    required this.expectedVersion,
    required this.expectedRoomVersion,
  });

  factory MembershipCommandInput.fromJson(Map<String, dynamic> json) {
    return MembershipCommandInput(
      commandId: json['command_id'] as String,
      expectedVersion: (json['expected_version'] as num).toInt(),
      expectedRoomVersion: (json['expected_room_version'] as num).toInt(),
    );
  }

  final String commandId;

  final int expectedVersion;

  final int expectedRoomVersion;

  Map<String, dynamic> toJson() {
    return {
      'command_id': commandId,
      'expected_version': expectedVersion,
      'expected_room_version': expectedRoomVersion,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('command_id') &&
        json['command_id'] is String &&
        json.containsKey('expected_version') &&
        json['expected_version'] is num &&
        json.containsKey('expected_room_version') &&
        json['expected_room_version'] is num;
  }

  MembershipCommandInput copyWith({
    String? commandId,
    int? expectedVersion,
    int? expectedRoomVersion,
  }) {
    return MembershipCommandInput(
      commandId: commandId ?? this.commandId,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      expectedRoomVersion: expectedRoomVersion ?? this.expectedRoomVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MembershipCommandInput &&
            commandId == other.commandId &&
            expectedVersion == other.expectedVersion &&
            expectedRoomVersion == other.expectedRoomVersion;
  }

  @override
  int get hashCode {
    return Object.hash(commandId, expectedVersion, expectedRoomVersion);
  }

  @override
  String toString() {
    return 'MembershipCommandInput(commandId: $commandId, expectedVersion: $expectedVersion, expectedRoomVersion: $expectedRoomVersion)';
  }
}
