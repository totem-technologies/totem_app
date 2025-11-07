// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceSchema _$SpaceSchemaFromJson(Map<String, dynamic> json) => SpaceSchema(
  title: json['title'] as String,
  slug: json['slug'] as String,
  dateCreated: DateTime.parse(json['date_created'] as String),
  dateModified: DateTime.parse(json['date_modified'] as String),
  subtitle: json['subtitle'] as String,
  author: PublicUserSchema.fromJson(json['author'] as Map<String, dynamic>),
  nextEvent: json['next_event'] == null
      ? null
      : NextEventSchema.fromJson(json['next_event'] as Map<String, dynamic>),
  imageUrl: json['image_url'] as String?,
  categories: (json['categories'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SpaceSchemaToJson(SpaceSchema instance) =>
    <String, dynamic>{
      'title': instance.title,
      'slug': instance.slug,
      'date_created': instance.dateCreated.toIso8601String(),
      'date_modified': instance.dateModified.toIso8601String(),
      'subtitle': instance.subtitle,
      'author': instance.author,
      'next_event': instance.nextEvent,
      'image_url': instance.imageUrl,
      'categories': instance.categories,
    };
