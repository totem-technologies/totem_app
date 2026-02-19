// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reorder_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReorderEvent _$ReorderEventFromJson(Map<String, dynamic> json) => ReorderEvent(
  talkingOrder: (json['talking_order'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  type: json['type'] as String? ?? 'reorder',
);

Map<String, dynamic> _$ReorderEventToJson(ReorderEvent instance) =>
    <String, dynamic>{
      'type': instance.type,
      'talking_order': instance.talkingOrder,
    };
