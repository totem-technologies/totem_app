// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'ban_participant_event.g.dart';

/// Keeper permanently bans a participant, removing them from the talking order.
@JsonSerializable()
class BanParticipantEvent {
  const BanParticipantEvent({
    required this.participantSlug,
    this.type = 'ban_participant',
  });

  factory BanParticipantEvent.fromJson(Map<String, Object?> json) =>
      _$BanParticipantEventFromJson(json);

  final String type;
  @JsonKey(name: 'participant_slug')
  final String participantSlug;

  Map<String, Object?> toJson() => _$BanParticipantEventToJson(this);
}
