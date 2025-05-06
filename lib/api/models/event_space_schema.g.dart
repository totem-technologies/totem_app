// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_space_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventSpaceSchema _$EventSpaceSchemaFromJson(Map<String, dynamic> json) =>
    EventSpaceSchema(
      author: PublicUserSchema.fromJson(json['author'] as Map<String, dynamic>),
      title: json['title'] as String,
      dateCreated: DateTime.parse(json['date_created'] as String),
      dateModified: DateTime.parse(json['date_modified'] as String),
      subtitle: json['subtitle'] as String,
      categories:
          (json['categories'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
      recurring: json['recurring'] as String,
      slug: json['slug'] as String?,
      shortDescription: json['short_description'] as String?,
      image: json['image'] as String?,
    );

Map<String, dynamic> _$EventSpaceSchemaToJson(EventSpaceSchema instance) =>
    <String, dynamic>{
      'author': instance.author,
      'title': instance.title,
      'slug': instance.slug,
      'date_created': instance.dateCreated.toIso8601String(),
      'date_modified': instance.dateModified.toIso8601String(),
      'subtitle': instance.subtitle,
      'categories': instance.categories,
      'short_description': instance.shortDescription,
      'recurring': instance.recurring,
      'image': instance.image,
    };
