import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/api/blog/blog_client.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/blog_post_list_schema.dart';
import 'package:totem_app/api/models/blog_post_schema.dart';
import 'package:totem_app/api/models/paged_blog_post_list_schema.dart';

class MockBlogClient extends Mock implements BlogClient {}

class MockMobileTotemApi extends Mock implements MobileTotemApi {}

Future<PagedBlogPostListSchema> testListBlogPosts(
  MobileTotemApi apiService,
) async {
  return apiService.blog.totemBlogMobileApiListPosts();
}

Future<BlogPostSchema> testGetBlogPost(
  MobileTotemApi apiService,
  String slug,
) async {
  return apiService.blog.totemBlogMobileApiPost(slug: slug);
}

void main() {
  group('Blog Repository Tests', () {
    late MockBlogClient mockBlogClient;
    late MockMobileTotemApi mockMobileTotemApi;

    setUpAll(() {
      registerFallbackValue(
        const PagedBlogPostListSchema(
          items: [],
          count: 0,
        ),
      );
      registerFallbackValue(const BlogPostSchema(title: 'Test Title'));
    });

    setUp(() {
      mockBlogClient = MockBlogClient();
      mockMobileTotemApi = MockMobileTotemApi();

      when(() => mockMobileTotemApi.blog).thenReturn(mockBlogClient);
    });

    group('listBlogPosts', () {
      test('should return blog posts successfully', () async {
        const testBlogPosts = PagedBlogPostListSchema(
          items: [
            BlogPostListSchema(
              slug: 'test-post-1',
              title: 'Test Post 1',
              summary: 'Test summary 1',
            ),
            BlogPostListSchema(
              slug: 'test-post-2',
              title: 'Test Post 2',
              summary: 'Test summary 2',
            ),
          ],
          count: 2,
        );

        when(
          () => mockBlogClient.totemBlogMobileApiListPosts(),
        ).thenAnswer((_) async => testBlogPosts);

        final result = await testListBlogPosts(mockMobileTotemApi);

        expect(result, equals(testBlogPosts));
        expect(result.items, hasLength(2));
        expect(result.items.first.slug, equals('test-post-1'));
        expect(result.items.last.slug, equals('test-post-2'));
        verify(() => mockBlogClient.totemBlogMobileApiListPosts()).called(1);
      });

      test('should handle DioException in listBlogPosts', () async {
        when(() => mockBlogClient.totemBlogMobileApiListPosts()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/blog/posts'),
            response: Response(
              requestOptions: RequestOptions(path: '/blog/posts'),
              statusCode: 500,
            ),
          ),
        );

        expect(
          () => testListBlogPosts(mockMobileTotemApi),
          throwsA(isA<DioException>()),
        );
        verify(() => mockBlogClient.totemBlogMobileApiListPosts()).called(1);
      });
    });

    group('blogPost', () {
      test('should return blog post successfully', () async {
        const testSlug = 'test-post-slug';
        const testBlogPost = BlogPostSchema(
          slug: testSlug,
          title: 'Test Post Title',
          summary: 'Test summary',
          contentHtml: 'Test content',
        );

        when(
          () => mockBlogClient.totemBlogMobileApiPost(slug: any(named: 'slug')),
        ).thenAnswer((_) async => testBlogPost);

        final result = await testGetBlogPost(mockMobileTotemApi, testSlug);

        expect(result, equals(testBlogPost));
        expect(result.slug, equals(testSlug));
        expect(result.title, equals('Test Post Title'));
        verify(
          () => mockBlogClient.totemBlogMobileApiPost(slug: testSlug),
        ).called(1);
      });

      test('should handle DioException in blogPost', () async {
        const testSlug = 'test-post-slug';
        when(
          () => mockBlogClient.totemBlogMobileApiPost(slug: any(named: 'slug')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/blog/posts/$testSlug'),
            response: Response(
              requestOptions: RequestOptions(path: '/blog/posts/$testSlug'),
              statusCode: 404,
            ),
          ),
        );

        expect(
          () => testGetBlogPost(mockMobileTotemApi, testSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockBlogClient.totemBlogMobileApiPost(slug: testSlug),
        ).called(1);
      });
    });
  });
}
