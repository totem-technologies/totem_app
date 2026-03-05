// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unban_participant_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnbanParticipantEvent _$UnbanParticipantEventFromJson(
  Map<String, dynamic> json,
) => UnbanParticipantEvent(
  participantSlug: json['participantSlug'] as String,
  type: json['type'] as String? ?? 'unban_participant',
);

Map<String, dynamic> _$UnbanParticipantEventToJson(
  UnbanParticipantEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'participantSlug': instance.participantSlug,
};
