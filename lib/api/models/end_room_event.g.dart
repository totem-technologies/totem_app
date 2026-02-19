// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'end_room_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EndRoomEvent _$EndRoomEventFromJson(Map<String, dynamic> json) => EndRoomEvent(
  reason: EndReason.fromJson(json['reason'] as String),
  type: json['type'] as String? ?? 'end_room',
);

Map<String, dynamic> _$EndRoomEventToJson(EndRoomEvent instance) =>
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
