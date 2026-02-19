// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ended_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EndedDetail _$EndedDetailFromJson(Map<String, dynamic> json) => EndedDetail(
  reason: EndReason.fromJson(json['reason'] as String),
  type: json['type'] as String? ?? 'ended',
);

Map<String, dynamic> _$EndedDetailToJson(EndedDetail instance) =>
    <String, dynamic>{
      'type': instance.type,
      'reason': _$EndReasonEnumMap[instance.reason]!,
    };

const _$EndReasonEnumMap = {
  EndReason.keeperEnded: 'keeper_ended',
  EndReason.keeperAbsent: 'keeper_absent',
  EndReason.roomEmpty: 'room_empty',
  EndReason.$unknown: r'$unknown',
};
