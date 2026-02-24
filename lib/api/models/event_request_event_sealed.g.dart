// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_request_event_sealed.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$EventRequestEventSealedToJson(
  EventRequestEventSealed instance,
) => <String, dynamic>{};

EventRequestEventSealedAcceptStickEvent
_$EventRequestEventSealedAcceptStickEventFromJson(Map<String, dynamic> json) =>
    EventRequestEventSealedAcceptStickEvent(type: json['type'] as String);

Map<String, dynamic> _$EventRequestEventSealedAcceptStickEventToJson(
  EventRequestEventSealedAcceptStickEvent instance,
) => <String, dynamic>{'type': instance.type};

EventRequestEventSealedEndRoomEvent
_$EventRequestEventSealedEndRoomEventFromJson(Map<String, dynamic> json) =>
    EventRequestEventSealedEndRoomEvent(
      type: json['type'] as String,
      reason: EndReason.fromJson(json['reason'] as String),
    );

Map<String, dynamic> _$EventRequestEventSealedEndRoomEventToJson(
  EventRequestEventSealedEndRoomEvent instance,
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

EventRequestEventSealedForcePassStickEvent
_$EventRequestEventSealedForcePassStickEventFromJson(
  Map<String, dynamic> json,
) => EventRequestEventSealedForcePassStickEvent(type: json['type'] as String);

Map<String, dynamic> _$EventRequestEventSealedForcePassStickEventToJson(
  EventRequestEventSealedForcePassStickEvent instance,
) => <String, dynamic>{'type': instance.type};

EventRequestEventSealedPassStickEvent
_$EventRequestEventSealedPassStickEventFromJson(Map<String, dynamic> json) =>
    EventRequestEventSealedPassStickEvent(type: json['type'] as String);

Map<String, dynamic> _$EventRequestEventSealedPassStickEventToJson(
  EventRequestEventSealedPassStickEvent instance,
) => <String, dynamic>{'type': instance.type};

EventRequestEventSealedReorderEvent
_$EventRequestEventSealedReorderEventFromJson(Map<String, dynamic> json) =>
    EventRequestEventSealedReorderEvent(
      type: json['type'] as String,
      talkingOrder: (json['talkingOrder'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$EventRequestEventSealedReorderEventToJson(
  EventRequestEventSealedReorderEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'talkingOrder': instance.talkingOrder,
};

EventRequestEventSealedStartRoomEvent
_$EventRequestEventSealedStartRoomEventFromJson(Map<String, dynamic> json) =>
    EventRequestEventSealedStartRoomEvent(type: json['type'] as String);

Map<String, dynamic> _$EventRequestEventSealedStartRoomEventToJson(
  EventRequestEventSealedStartRoomEvent instance,
) => <String, dynamic>{'type': instance.type};
