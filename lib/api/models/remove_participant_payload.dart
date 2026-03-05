// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'remove_reason.dart';

part 'remove_participant_payload.g.dart';

@JsonSerializable()
class RemoveParticipantPayload {
  const RemoveParticipantPayload({
    required this.identity,
    required this.reason,
    this.action = 'remove_participant',
  });

  factory RemoveParticipantPayload.fromJson(Map<String, Object?> json) =>
      _$RemoveParticipantPayloadFromJson(json);

  final String action;
  final String identity;
  final RemoveReason reason;

  Map<String, Object?> toJson() => _$RemoveParticipantPayloadToJson(this);
}
