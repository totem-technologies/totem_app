// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceSchema _$SpaceSchemaFromJson(Map<String, dynamic> json) => SpaceSchema(
  author: PublicUserSchema.fromJson(json['author'] as Map<String, dynamic>),
  title: json['title'] as String,
  dateCreated: DateTime.parse(json['date_created'] as String),
  dateModified: DateTime.parse(json['date_modified'] as String),
  subtitle: json['subtitle'] as String,
  slug: json['slug'] as String?,
);

Map<String, dynamic> _$SpaceSchemaToJson(SpaceSchema instance) =>
    <String, dynamic>{
      'author': instance.author,
      'title': instance.title,
      'slug': instance.slug,
      'date_created': instance.dateCreated.toIso8601String(),
      'date_modified': instance.dateModified.toIso8601String(),
      'subtitle': instance.subtitle,
    };
