// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobile_space_detail_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MobileSpaceDetailSchema _$MobileSpaceDetailSchemaFromJson(
  Map<String, dynamic> json,
) => MobileSpaceDetailSchema(
  slug: json['slug'] as String,
  title: json['title'] as String,
  imageLink: json['image_link'] as String?,
  shortDescription: json['short_description'] as String,
  content: json['content'] as String,
  author: PublicUserSchema.fromJson(json['author'] as Map<String, dynamic>),
  category: json['category'] as String?,
  subscribers: (json['subscribers'] as num).toInt(),
  recurring: json['recurring'] as String?,
  price: (json['price'] as num).toInt(),
  nextEvents: (json['next_events'] as List<dynamic>)
      .map((e) => NextEventSchema.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MobileSpaceDetailSchemaToJson(
  MobileSpaceDetailSchema instance,
) => <String, dynamic>{
  'slug': instance.slug,
  'title': instance.title,
  'image_link': instance.imageLink,
  'short_description': instance.shortDescription,
  'content': instance.content,
  'author': instance.author,
  'category': instance.category,
  'subscribers': instance.subscribers,
  'recurring': instance.recurring,
  'price': instance.price,
  'next_events': instance.nextEvents,
};
