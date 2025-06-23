// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'blog_post_list_schema.dart';

part 'paged_blog_post_list_schema.g.dart';

@JsonSerializable()
class PagedBlogPostListSchema {
  const PagedBlogPostListSchema({
    required this.items,
    required this.count,
  });

  factory PagedBlogPostListSchema.fromJson(Map<String, Object?> json) =>
      _$PagedBlogPostListSchemaFromJson(json);

  final List<BlogPostListSchema> items;
  final int count;

  Map<String, Object?> toJson() => _$PagedBlogPostListSchemaToJson(this);
}
