// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remove_participant_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RemoveParticipantPayload _$RemoveParticipantPayloadFromJson(
  Map<String, dynamic> json,
) => RemoveParticipantPayload(
  identity: json['identity'] as String,
  reason: RemoveReason.fromJson(json['reason'] as String),
  action: json['action'] as String? ?? 'remove_participant',
);

Map<String, dynamic> _$RemoveParticipantPayloadToJson(
  RemoveParticipantPayload instance,
) => <String, dynamic>{
  'action': instance.action,
  'identity': instance.identity,
  'reason': _$RemoveReasonEnumMap[instance.reason]!,
};

const _$RemoveReasonEnumMap = {
  RemoveReason.remove: 'remove',
  RemoveReason.ban: 'ban',
  RemoveReason.$unknown: r'$unknown',
};
