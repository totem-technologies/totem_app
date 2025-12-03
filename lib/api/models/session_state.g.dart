// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionState _$SessionStateFromJson(Map<String, dynamic> json) => SessionState(
  speakingOrder: (json['speaking_order'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  speakingNow: json['speaking_now'] as String?,
  status: json['status'] == null
      ? SessionStatus.waiting
      : SessionStatus.fromJson(json['status'] as String),
  totemStatus: json['totem_status'] == null
      ? TotemStatus.none
      : TotemStatus.fromJson(json['totem_status'] as String),
);

Map<String, dynamic> _$SessionStateToJson(SessionState instance) =>
    <String, dynamic>{
      'status': _$SessionStatusEnumMap[instance.status]!,
      'speaking_order': instance.speakingOrder,
      'speaking_now': instance.speakingNow,
      'totem_status': _$TotemStatusEnumMap[instance.totemStatus]!,
    };

const _$SessionStatusEnumMap = {
  SessionStatus.waiting: 'waiting',
  SessionStatus.started: 'started',
  SessionStatus.ended: 'ended',
  SessionStatus.$unknown: r'$unknown',
};

const _$TotemStatusEnumMap = {
  TotemStatus.none: 'none',
  TotemStatus.accepted: 'accepted',
  TotemStatus.passing: 'passing',
  TotemStatus.$unknown: r'$unknown',
};
