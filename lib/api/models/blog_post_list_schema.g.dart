// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_post_list_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlogPostListSchema _$BlogPostListSchemaFromJson(Map<String, dynamic> json) =>
    BlogPostListSchema(
      title: json['title'] as String,
      datePublished: DateTime.parse(json['date_published'] as String),
      author:
          json['author'] == null
              ? null
              : PublicUserSchema.fromJson(
                json['author'] as Map<String, dynamic>,
              ),
      headerImageUrl: json['header_image_url'] as String?,
      subtitle: json['subtitle'] as String?,
      slug: json['slug'] as String?,
    );

Map<String, dynamic> _$BlogPostListSchemaToJson(BlogPostListSchema instance) =>
    <String, dynamic>{
      'author': instance.author,
      'header_image_url': instance.headerImageUrl,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'date_published': instance.datePublished.toIso8601String(),
      'slug': instance.slug,
    };
