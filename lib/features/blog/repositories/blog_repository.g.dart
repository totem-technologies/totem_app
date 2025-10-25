// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(listBlogPosts)
const listBlogPostsProvider = ListBlogPostsProvider._();

final class ListBlogPostsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PagedBlogPostListSchema>,
          PagedBlogPostListSchema,
          FutureOr<PagedBlogPostListSchema>
        >
    with
        $FutureModifier<PagedBlogPostListSchema>,
        $FutureProvider<PagedBlogPostListSchema> {
  const ListBlogPostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listBlogPostsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listBlogPostsHash();

  @$internal
  @override
  $FutureProviderElement<PagedBlogPostListSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PagedBlogPostListSchema> create(Ref ref) {
    return listBlogPosts(ref);
  }
}

String _$listBlogPostsHash() => r'a02c79b351043c4205736535010e5a0502bf14a5';

@ProviderFor(blogPost)
const blogPostProvider = BlogPostFamily._();

final class BlogPostProvider
    extends
        $FunctionalProvider<
          AsyncValue<BlogPostSchema>,
          BlogPostSchema,
          FutureOr<BlogPostSchema>
        >
    with $FutureModifier<BlogPostSchema>, $FutureProvider<BlogPostSchema> {
  const BlogPostProvider._({
    required BlogPostFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'blogPostProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blogPostHash();

  @override
  String toString() {
    return r'blogPostProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BlogPostSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BlogPostSchema> create(Ref ref) {
    final argument = this.argument as String;
    return blogPost(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BlogPostProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blogPostHash() => r'85dac9d60c002f4c61fcb3bfc58eb7e34a6af76f';

final class BlogPostFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BlogPostSchema>, String> {
  const BlogPostFamily._()
    : super(
        retry: null,
        name: r'blogPostProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BlogPostProvider call(String slug) =>
      BlogPostProvider._(argument: slug, from: this);

  @override
  String toString() => r'blogPostProvider';
}
