// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class KeeperDecisionInput {
  const KeeperDecisionInput({
    required this.commandId,
    required this.requestId,
    required this.attemptId,
    required this.expectedVersion,
    required this.expectedRoomVersion,
  });

  factory KeeperDecisionInput.fromJson(Map<String, dynamic> json) {
    return KeeperDecisionInput(
      commandId: json['command_id'] as String,
      requestId: json['request_id'] as String,
      attemptId: json['attempt_id'] as String,
      expectedVersion: (json['expected_version'] as num).toInt(),
      expectedRoomVersion: (json['expected_room_version'] as num).toInt(),
    );
  }

  final String commandId;

  final String requestId;

  final String attemptId;

  final int expectedVersion;

  final int expectedRoomVersion;

  Map<String, dynamic> toJson() {
    return {
      'command_id': commandId,
      'request_id': requestId,
      'attempt_id': attemptId,
      'expected_version': expectedVersion,
      'expected_room_version': expectedRoomVersion,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('command_id') &&
        json['command_id'] is String &&
        json.containsKey('request_id') &&
        json['request_id'] is String &&
        json.containsKey('attempt_id') &&
        json['attempt_id'] is String &&
        json.containsKey('expected_version') &&
        json['expected_version'] is num &&
        json.containsKey('expected_room_version') &&
        json['expected_room_version'] is num;
  }

  KeeperDecisionInput copyWith({
    String? commandId,
    String? requestId,
    String? attemptId,
    int? expectedVersion,
    int? expectedRoomVersion,
  }) {
    return KeeperDecisionInput(
      commandId: commandId ?? this.commandId,
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      expectedRoomVersion: expectedRoomVersion ?? this.expectedRoomVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KeeperDecisionInput &&
            commandId == other.commandId &&
            requestId == other.requestId &&
            attemptId == other.attemptId &&
            expectedVersion == other.expectedVersion &&
            expectedRoomVersion == other.expectedRoomVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      commandId,
      requestId,
      attemptId,
      expectedVersion,
      expectedRoomVersion,
    );
  }

  @override
  String toString() {
    return 'KeeperDecisionInput(commandId: $commandId, requestId: $requestId, attemptId: $attemptId, expectedVersion: $expectedVersion, expectedRoomVersion: $expectedRoomVersion)';
  }
}
