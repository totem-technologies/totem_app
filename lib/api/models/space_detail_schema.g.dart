// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_detail_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpaceDetailSchema _$SpaceDetailSchemaFromJson(Map<String, dynamic> json) =>
    SpaceDetailSchema(
      slug: json['slug'] as String,
      title: json['title'] as String,
      imageLink: json['image_link'] as String?,
      description: json['description'] as String,
      author: PublicUserSchema.fromJson(json['author'] as Map<String, dynamic>),
      nextEvent: NextEventSchema.fromJson(
        json['nextEvent'] as Map<String, dynamic>,
      ),
      category: json['category'] as String?,
    );

Map<String, dynamic> _$SpaceDetailSchemaToJson(SpaceDetailSchema instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'title': instance.title,
      'image_link': instance.imageLink,
      'description': instance.description,
      'author': instance.author,
      'nextEvent': instance.nextEvent,
      'category': instance.category,
    };
