// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/blog_post_schema.dart';
import '../models/paged_blog_post_list_schema.dart';

part 'blog_client.g.dart';

@RestApi()
abstract class BlogClient {
  factory BlogClient(Dio dio, {String? baseUrl}) = _BlogClient;

  /// List Posts.
  ///
  /// List all blog posts.
  @GET('/api/mobile/protected/blog/posts')
  Future<PagedBlogPostListSchema> totemBlogMobileApiListPosts({
    @Query('limit') int? limit = 100,
    @Query('offset') int? offset = 0,
  });

  /// Post
  @GET('/api/mobile/protected/blog/post/{slug}')
  Future<BlogPostSchema> totemBlogMobileApiPost({
    @Path('slug') required String slug,
  });
}
