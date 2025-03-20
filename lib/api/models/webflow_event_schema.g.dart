// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webflow_event_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebflowEventSchema _$WebflowEventSchemaFromJson(Map<String, dynamic> json) =>
    WebflowEventSchema(
      start: json['start'] as String,
      name: json['name'] as String,
      keeperName: json['keeper_name'] as String,
      keeperUsername: json['keeper_username'] as String,
      joinLink: json['join_link'] as String,
      imageLink: json['image_link'] as String?,
      keeperImageLink: json['keeper_image_link'] as String?,
    );

Map<String, dynamic> _$WebflowEventSchemaToJson(WebflowEventSchema instance) =>
    <String, dynamic>{
      'start': instance.start,
      'name': instance.name,
      'keeper_name': instance.keeperName,
      'keeper_username': instance.keeperUsername,
      'join_link': instance.joinLink,
      'image_link': instance.imageLink,
      'keeper_image_link': instance.keeperImageLink,
    };
