import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/blog_post_schema.dart';
import 'package:totem_app/api/models/paged_blog_post_list_schema.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

part 'blog_repository.g.dart';

@riverpod
Future<PagedBlogPostListSchema> listBlogPosts(Ref ref) async {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<PagedBlogPostListSchema>(
    apiCall: () => apiService.blog.totemBlogMobileApiListPosts(),
    operationName: 'list blog posts',
  );
}

@riverpod
Future<BlogPostSchema> blogPost(Ref ref, String slug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<BlogPostSchema>(
    apiCall: () => apiService.blog.totemBlogMobileApiPost(slug: slug),
    operationName: 'get blog post',
  );
}
