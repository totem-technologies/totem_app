import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/blog_post_schema.dart';
import 'package:totem_app/api/models/paged_blog_post_list_schema.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'blog_repository.g.dart';

@riverpod
Future<PagedBlogPostListSchema> listBlogPosts(Ref ref) async {
  final apiService = ref.watch(mobileApiServiceProvider);
  return apiService.blog.totemBlogMobileApiListPosts();
}

@riverpod
Future<BlogPostSchema> blogPost(Ref ref, String slug) async {
  final apiService = ref.watch(mobileApiServiceProvider);
  return apiService.blog.totemBlogMobileApiPost(slug: slug);
}
