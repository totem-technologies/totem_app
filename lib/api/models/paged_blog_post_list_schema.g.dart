// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_blog_post_list_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedBlogPostListSchema _$PagedBlogPostListSchemaFromJson(
  Map<String, dynamic> json,
) => PagedBlogPostListSchema(
  items:
      (json['items'] as List<dynamic>)
          .map((e) => BlogPostListSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$PagedBlogPostListSchemaToJson(
  PagedBlogPostListSchema instance,
) => <String, dynamic>{'items': instance.items, 'count': instance.count};
