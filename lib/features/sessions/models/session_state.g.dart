// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionState _$SessionStateFromJson(Map<String, dynamic> json) => SessionState(
  status: $enumDecode(_$SessionStatusEnumMap, json['status']),
  speakingNow: json['speaking_now'] as String?,
  speakingOrder: (json['speaking_order'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SessionStateToJson(SessionState instance) =>
    <String, dynamic>{
      'status': _$SessionStatusEnumMap[instance.status]!,
      'speaking_now': instance.speakingNow,
      'speaking_order': instance.speakingOrder,
    };

const _$SessionStatusEnumMap = {
  SessionStatus.waiting: 'waiting',
  SessionStatus.started: 'started',
  SessionStatus.ending: 'ending',
  SessionStatus.ended: 'ended',
};
