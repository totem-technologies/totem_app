// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'public_user_schema.dart';

part 'blog_post_schema.g.dart';

@JsonSerializable()
class BlogPostSchema {
  const BlogPostSchema({
    required this.title,
    this.publish = false,
    this.readTime = 1,
    this.author,
    this.headerImageUrl,
    this.contentHtml,
    this.subtitle,
    this.datePublished,
    this.slug,
    this.summary,
  });

  factory BlogPostSchema.fromJson(Map<String, Object?> json) =>
      _$BlogPostSchemaFromJson(json);

  final PublicUserSchema? author;
  @JsonKey(name: 'header_image_url')
  final String? headerImageUrl;
  @JsonKey(name: 'content_html')
  final String? contentHtml;
  final String title;
  final String? subtitle;
  @JsonKey(name: 'date_published')
  final DateTime? datePublished;
  final String? slug;
  final bool publish;

  /// Estimated reading time in minutes (auto-calculated)
  @JsonKey(name: 'read_time')
  final int readTime;

  /// Short summary of the blog post to show in list pages. No Markdown allowed. Max 2000 characters.
  final String? summary;

  Map<String, Object?> toJson() => _$BlogPostSchemaToJson(this);
}
