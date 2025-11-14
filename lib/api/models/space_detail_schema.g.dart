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
      shortDescription: json['short_description'] as String,
      content: json['content'] as String,
      author: PublicUserSchema.fromJson(json['author'] as Map<String, dynamic>),
      nextEvent: json['next_event'] == null
          ? null
          : NextEventSchema.fromJson(
              json['next_event'] as Map<String, dynamic>,
            ),
      category: json['category'] as String?,
      subscribers: (json['subscribers'] as num).toInt(),
      recurring: json['recurring'] as String?,
      price: (json['price'] as num).toInt(),
    );

Map<String, dynamic> _$SpaceDetailSchemaToJson(SpaceDetailSchema instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'title': instance.title,
      'image_link': instance.imageLink,
      'short_description': instance.shortDescription,
      'content': instance.content,
      'author': instance.author,
      'next_event': instance.nextEvent,
      'category': instance.category,
      'subscribers': instance.subscribers,
      'recurring': instance.recurring,
      'price': instance.price,
    };
