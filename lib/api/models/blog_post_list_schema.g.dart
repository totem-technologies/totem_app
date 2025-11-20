// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_post_list_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlogPostListSchema _$BlogPostListSchemaFromJson(Map<String, dynamic> json) =>
    BlogPostListSchema(
      title: json['title'] as String,
      publish: json['publish'] as bool? ?? false,
      readTime: (json['read_time'] as num?)?.toInt() ?? 1,
      author: json['author'] == null
          ? null
          : PublicUserSchema.fromJson(json['author'] as Map<String, dynamic>),
      headerImageUrl: json['header_image_url'] as String?,
      subtitle: json['subtitle'] as String?,
      datePublished: json['date_published'] == null
          ? null
          : DateTime.parse(json['date_published'] as String),
      slug: json['slug'] as String?,
      summary: json['summary'] as String?,
    );

Map<String, dynamic> _$BlogPostListSchemaToJson(BlogPostListSchema instance) =>
    <String, dynamic>{
      'author': instance.author,
      'header_image_url': instance.headerImageUrl,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'date_published': instance.datePublished?.toIso8601String(),
      'slug': instance.slug,
      'publish': instance.publish,
      'read_time': instance.readTime,
      'summary': instance.summary,
    };
