// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_calendar_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventCalendarSchema _$EventCalendarSchemaFromJson(Map<String, dynamic> json) =>
    EventCalendarSchema(
      title: json['title'] as String,
      start: json['start'] as String,
      slug: json['slug'] as String,
      url: json['url'] as String,
    );

Map<String, dynamic> _$EventCalendarSchemaToJson(
  EventCalendarSchema instance,
) => <String, dynamic>{
  'title': instance.title,
  'start': instance.start,
  'slug': instance.slug,
  'url': instance.url,
};
