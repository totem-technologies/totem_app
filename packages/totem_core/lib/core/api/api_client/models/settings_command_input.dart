// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SettingsCommandInput {
  const SettingsCommandInput({
    required this.commandId,
    required this.approvalRequired,
    required this.expectedRevision,
    required this.expectedRoomVersion,
  });

  factory SettingsCommandInput.fromJson(Map<String, dynamic> json) {
    return SettingsCommandInput(
      commandId: json['command_id'] as String,
      approvalRequired: json['approval_required'] as bool,
      expectedRevision: (json['expected_revision'] as num).toInt(),
      expectedRoomVersion: (json['expected_room_version'] as num).toInt(),
    );
  }

  final String commandId;

  final bool approvalRequired;

  final int expectedRevision;

  final int expectedRoomVersion;

  Map<String, dynamic> toJson() {
    return {
      'command_id': commandId,
      'approval_required': approvalRequired,
      'expected_revision': expectedRevision,
      'expected_room_version': expectedRoomVersion,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('command_id') &&
        json['command_id'] is String &&
        json.containsKey('approval_required') &&
        json['approval_required'] is bool &&
        json.containsKey('expected_revision') &&
        json['expected_revision'] is num &&
        json.containsKey('expected_room_version') &&
        json['expected_room_version'] is num;
  }

  SettingsCommandInput copyWith({
    String? commandId,
    bool? approvalRequired,
    int? expectedRevision,
    int? expectedRoomVersion,
  }) {
    return SettingsCommandInput(
      commandId: commandId ?? this.commandId,
      approvalRequired: approvalRequired ?? this.approvalRequired,
      expectedRevision: expectedRevision ?? this.expectedRevision,
      expectedRoomVersion: expectedRoomVersion ?? this.expectedRoomVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SettingsCommandInput &&
            commandId == other.commandId &&
            approvalRequired == other.approvalRequired &&
            expectedRevision == other.expectedRevision &&
            expectedRoomVersion == other.expectedRoomVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      commandId,
      approvalRequired,
      expectedRevision,
      expectedRoomVersion,
    );
  }

  @override
  String toString() {
    return 'SettingsCommandInput(commandId: $commandId, approvalRequired: $approvalRequired, expectedRevision: $expectedRevision, expectedRoomVersion: $expectedRoomVersion)';
  }
}
