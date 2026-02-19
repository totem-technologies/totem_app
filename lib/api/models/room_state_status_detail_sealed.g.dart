// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_state_status_detail_sealed.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$RoomStateStatusDetailSealedToJson(
  RoomStateStatusDetailSealed instance,
) => <String, dynamic>{};

RoomStateStatusDetailSealedActiveDetail
_$RoomStateStatusDetailSealedActiveDetailFromJson(Map<String, dynamic> json) =>
    RoomStateStatusDetailSealedActiveDetail(type: json['type'] as String);

Map<String, dynamic> _$RoomStateStatusDetailSealedActiveDetailToJson(
  RoomStateStatusDetailSealedActiveDetail instance,
) => <String, dynamic>{'type': instance.type};

RoomStateStatusDetailSealedEndedDetail
_$RoomStateStatusDetailSealedEndedDetailFromJson(Map<String, dynamic> json) =>
    RoomStateStatusDetailSealedEndedDetail(
      type: json['type'] as String,
      reason: EndReason.fromJson(json['reason'] as String),
    );

Map<String, dynamic> _$RoomStateStatusDetailSealedEndedDetailToJson(
  RoomStateStatusDetailSealedEndedDetail instance,
) => <String, dynamic>{
  'type': instance.type,
  'reason': _$EndReasonEnumMap[instance.reason]!,
};

const _$EndReasonEnumMap = {
  EndReason.keeperEnded: 'keeper_ended',
  EndReason.keeperAbsent: 'keeper_absent',
  EndReason.roomEmpty: 'room_empty',
  EndReason.$unknown: r'$unknown',
};

RoomStateStatusDetailSealedWaitingRoomDetail
_$RoomStateStatusDetailSealedWaitingRoomDetailFromJson(
  Map<String, dynamic> json,
) => RoomStateStatusDetailSealedWaitingRoomDetail(type: json['type'] as String);

Map<String, dynamic> _$RoomStateStatusDetailSealedWaitingRoomDetailToJson(
  RoomStateStatusDetailSealedWaitingRoomDetail instance,
) => <String, dynamic>{'type': instance.type};
