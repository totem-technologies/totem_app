// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Machine-readable error codes. Clients switch on these, not on messages.
/// Add new codes here as needed — the OpenAPI spec will update automatically.
@JsonEnum()
enum ErrorCode {
  @JsonValue('not_in_room')
  notInRoom('not_in_room'),
  @JsonValue('not_keeper')
  notKeeper('not_keeper'),
  @JsonValue('not_current_speaker')
  notCurrentSpeaker('not_current_speaker'),
  @JsonValue('not_next_speaker')
  notNextSpeaker('not_next_speaker'),
  @JsonValue('invalid_transition')
  invalidTransition('invalid_transition'),
  @JsonValue('room_not_active')
  roomNotActive('room_not_active'),
  @JsonValue('room_not_waiting')
  roomNotWaiting('room_not_waiting'),
  @JsonValue('room_already_ended')
  roomAlreadyEnded('room_already_ended'),
  @JsonValue('invalid_participant_order')
  invalidParticipantOrder('invalid_participant_order'),
  @JsonValue('stale_version')
  staleVersion('stale_version'),
  @JsonValue('not_joinable')
  notJoinable('not_joinable'),
  @JsonValue('livekit_error')
  livekitError('livekit_error'),
  @JsonValue('not_found')
  notFound('not_found'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ErrorCode(this.json);

  factory ErrorCode.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<ErrorCode> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
