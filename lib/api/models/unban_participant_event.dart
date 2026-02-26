// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'unban_participant_event.g.dart';

/// Keeper lifts a ban, allowing the participant to rejoin.
@JsonSerializable()
class UnbanParticipantEvent {
  const UnbanParticipantEvent({
    required this.participantSlug,
    this.type = 'unban_participant',
  });

  factory UnbanParticipantEvent.fromJson(Map<String, Object?> json) =>
      _$UnbanParticipantEventFromJson(json);

  final String type;
  @JsonKey(name: 'participant_slug')
  final String participantSlug;

  Map<String, Object?> toJson() => _$UnbanParticipantEventToJson(this);
}
