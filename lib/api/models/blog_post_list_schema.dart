// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'public_user_schema.dart';

part 'blog_post_list_schema.g.dart';

@JsonSerializable()
class BlogPostListSchema {
  const BlogPostListSchema({
    required this.title,
    this.publish = false,
    this.readTime = 1,
    this.author,
    this.headerImageUrl,
    this.subtitle,
    this.datePublished,
    this.slug,
    this.summary,
  });

  factory BlogPostListSchema.fromJson(Map<String, Object?> json) =>
      _$BlogPostListSchemaFromJson(json);

  final PublicUserSchema? author;
  @JsonKey(name: 'header_image_url')
  final String? headerImageUrl;
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

  Map<String, Object?> toJson() => _$BlogPostListSchemaToJson(this);
}
