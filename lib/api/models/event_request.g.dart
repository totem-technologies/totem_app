// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventRequest _$EventRequestFromJson(Map<String, dynamic> json) => EventRequest(
  event: EventRequestEventSealed.fromJson(
    json['event'] as Map<String, dynamic>,
  ),
  lastSeenVersion: (json['last_seen_version'] as num).toInt(),
);

Map<String, dynamic> _$EventRequestToJson(EventRequest instance) =>
    <String, dynamic>{
      'event': instance.event.toJson(),
      'last_seen_version': instance.lastSeenVersion,
    };
