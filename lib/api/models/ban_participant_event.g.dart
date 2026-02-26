// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ban_participant_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BanParticipantEvent _$BanParticipantEventFromJson(Map<String, dynamic> json) =>
    BanParticipantEvent(
      participantSlug: json['participant_slug'] as String,
      type: json['type'] as String? ?? 'ban_participant',
    );

Map<String, dynamic> _$BanParticipantEventToJson(
  BanParticipantEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'participant_slug': instance.participantSlug,
};
