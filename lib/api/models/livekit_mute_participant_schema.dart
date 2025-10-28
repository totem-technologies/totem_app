// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'livekit_mute_participant_schema.g.dart';

@JsonSerializable()
class LivekitMuteParticipantSchema {
  const LivekitMuteParticipantSchema({
    required this.order,
  });

  factory LivekitMuteParticipantSchema.fromJson(Map<String, Object?> json) =>
      _$LivekitMuteParticipantSchemaFromJson(json);

  final List<String> order;

  Map<String, Object?> toJson() => _$LivekitMuteParticipantSchemaToJson(this);
}
