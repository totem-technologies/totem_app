// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_post_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlogPostSchema _$BlogPostSchemaFromJson(Map<String, dynamic> json) =>
    BlogPostSchema(
      title: json['title'] as String,
      datePublished: DateTime.parse(json['date_published'] as String),
      publish: json['publish'] as bool? ?? false,
      author:
          json['author'] == null
              ? null
              : PublicUserSchema.fromJson(
                json['author'] as Map<String, dynamic>,
              ),
      headerImageUrl: json['header_image_url'] as String?,
      contentHtml: json['content_html'] as String?,
      subtitle: json['subtitle'] as String?,
      slug: json['slug'] as String?,
    );

Map<String, dynamic> _$BlogPostSchemaToJson(BlogPostSchema instance) =>
    <String, dynamic>{
      'author': instance.author,
      'header_image_url': instance.headerImageUrl,
      'content_html': instance.contentHtml,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'date_published': instance.datePublished.toIso8601String(),
      'slug': instance.slug,
      'publish': instance.publish,
    };
