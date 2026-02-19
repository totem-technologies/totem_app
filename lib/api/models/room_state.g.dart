// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoomState _$RoomStateFromJson(Map<String, dynamic> json) => RoomState(
  sessionSlug: json['session_slug'] as String,
  version: (json['version'] as num).toInt(),
  status: RoomStatus.fromJson(json['status'] as String),
  turnState: TurnState.fromJson(json['turn_state'] as String),
  statusDetail: RoomStateStatusDetailSealed.fromJson(
    json['status_detail'] as Map<String, dynamic>,
  ),
  talkingOrder: (json['talking_order'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  keeper: json['keeper'] as String,
  currentSpeaker: json['current_speaker'] as String?,
  nextSpeaker: json['next_speaker'] as String?,
);

Map<String, dynamic> _$RoomStateToJson(RoomState instance) => <String, dynamic>{
  'session_slug': instance.sessionSlug,
  'version': instance.version,
  'status': _$RoomStatusEnumMap[instance.status]!,
  'turn_state': _$TurnStateEnumMap[instance.turnState]!,
  'status_detail': instance.statusDetail,
  'current_speaker': instance.currentSpeaker,
  'next_speaker': instance.nextSpeaker,
  'talking_order': instance.talkingOrder,
  'keeper': instance.keeper,
};

const _$RoomStatusEnumMap = {
  RoomStatus.waitingRoom: 'waiting_room',
  RoomStatus.active: 'active',
  RoomStatus.ended: 'ended',
  RoomStatus.$unknown: r'$unknown',
};

const _$TurnStateEnumMap = {
  TurnState.idle: 'idle',
  TurnState.speaking: 'speaking',
  TurnState.passing: 'passing',
  TurnState.$unknown: r'$unknown',
};
