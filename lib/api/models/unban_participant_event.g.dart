// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unban_participant_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnbanParticipantEvent _$UnbanParticipantEventFromJson(
  Map<String, dynamic> json,
) => UnbanParticipantEvent(
  participantSlug: json['participant_slug'] as String,
  type: json['type'] as String? ?? 'unban_participant',
);

Map<String, dynamic> _$UnbanParticipantEventToJson(
  UnbanParticipantEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'participant_slug': instance.participantSlug,
};
