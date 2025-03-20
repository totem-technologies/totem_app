// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_list_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventListSchema _$EventListSchemaFromJson(Map<String, dynamic> json) =>
    EventListSchema(
      space: SpaceSchema.fromJson(json['space'] as Map<String, dynamic>),
      url: json['url'] as String,
      start: DateTime.parse(json['start'] as String),
      dateCreated: DateTime.parse(json['date_created'] as String),
      dateModified: DateTime.parse(json['date_modified'] as String),
      slug: json['slug'] as String?,
      title: json['title'] as String?,
    );

Map<String, dynamic> _$EventListSchemaToJson(EventListSchema instance) =>
    <String, dynamic>{
      'space': instance.space,
      'url': instance.url,
      'start': instance.start.toIso8601String(),
      'slug': instance.slug,
      'date_created': instance.dateCreated.toIso8601String(),
      'date_modified': instance.dateModified.toIso8601String(),
      'title': instance.title,
    };
