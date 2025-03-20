// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'next_event_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NextEventSchema _$NextEventSchemaFromJson(Map<String, dynamic> json) =>
    NextEventSchema(
      slug: json['slug'] as String,
      start: json['start'] as String,
      link: json['link'] as String,
      title: json['title'] as String?,
    );

Map<String, dynamic> _$NextEventSchemaToJson(NextEventSchema instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'start': instance.start,
      'link': instance.link,
      'title': instance.title,
    };
