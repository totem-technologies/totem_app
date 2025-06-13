// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listBlogPostsHash() => r'a02c79b351043c4205736535010e5a0502bf14a5';

/// See also [listBlogPosts].
@ProviderFor(listBlogPosts)
final listBlogPostsProvider =
    AutoDisposeFutureProvider<PagedBlogPostListSchema>.internal(
      listBlogPosts,
      name: r'listBlogPostsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$listBlogPostsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ListBlogPostsRef =
    AutoDisposeFutureProviderRef<PagedBlogPostListSchema>;
String _$blogPostHash() => r'85dac9d60c002f4c61fcb3bfc58eb7e34a6af76f';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [blogPost].
@ProviderFor(blogPost)
const blogPostProvider = BlogPostFamily();

/// See also [blogPost].
class BlogPostFamily extends Family<AsyncValue<BlogPostSchema>> {
  /// See also [blogPost].
  const BlogPostFamily();

  /// See also [blogPost].
  BlogPostProvider call(String slug) {
    return BlogPostProvider(slug);
  }

  @override
  BlogPostProvider getProviderOverride(covariant BlogPostProvider provider) {
    return call(provider.slug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'blogPostProvider';
}

/// See also [blogPost].
class BlogPostProvider extends AutoDisposeFutureProvider<BlogPostSchema> {
  /// See also [blogPost].
  BlogPostProvider(String slug)
    : this._internal(
        (ref) => blogPost(ref as BlogPostRef, slug),
        from: blogPostProvider,
        name: r'blogPostProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$blogPostHash,
        dependencies: BlogPostFamily._dependencies,
        allTransitiveDependencies: BlogPostFamily._allTransitiveDependencies,
        slug: slug,
      );

  BlogPostProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<BlogPostSchema> Function(BlogPostRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BlogPostProvider._internal(
        (ref) => create(ref as BlogPostRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<BlogPostSchema> createElement() {
    return _BlogPostProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BlogPostProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BlogPostRef on AutoDisposeFutureProviderRef<BlogPostSchema> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _BlogPostProviderElement
    extends AutoDisposeFutureProviderElement<BlogPostSchema>
    with BlogPostRef {
  _BlogPostProviderElement(super.provider);

  @override
  String get slug => (origin as BlogPostProvider).slug;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
