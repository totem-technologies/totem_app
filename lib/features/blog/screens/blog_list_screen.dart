import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/widgets/blog_card.dart';
import 'package:totem_app/features/blog/widgets/featured_blog_post.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

const bool isBlogPostUpdateReady = false;

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogs = ref.watch(listBlogPostsProvider);
    if (isBlogPostUpdateReady) {
      return blogs.when(
        data: (data) {
          if (data.items.isEmpty) {
            return const Center(child: Text('No blog posts available'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                padding: EdgeInsetsDirectional.zero,
                children: [
                  FeaturedBlogPost.fromBlogPostSchema(data.items.first),
                  const SizedBox(height: 20),
                  ...List.generate(
                    10,
                    (index) => const Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: 20,
                        end: 20,
                        bottom: 20,
                      ),
                      child: Placeholder(
                        fallbackHeight: 350,
                        fallbackWidth: 350,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        error: (error, _) => ErrorScreen(
          error: error,
          showHomeButton: false,
          onRetry: () => ref.refresh(listBlogPostsProvider.future),
        ),
        loading: () => const LoadingIndicator(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return blogs.when<Widget>(
              data: (data) {
                if (data.items.isEmpty) {
                  return const Center(child: Text('No blog posts available'));
                }

                return RefreshIndicator.adaptive(
                  onRefresh: () => ref.refresh(listBlogPostsProvider.future),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 20,
                            end: 20,
                            top: 20,
                            bottom: 10,
                          ),
                          child: SizedBox(
                            height: clampDouble(
                              constraints.maxHeight * 0.45,
                              200,
                              double.infinity,
                            ),
                            child: BlogPostCard.fromBlogPostSchema(
                              data.items.first,
                              isLarge: true,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 20,
                          end: 20,
                          bottom: 20,
                        ),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 12 / 16,
                              ),
                          itemCount: data.items.sublist(1).length,
                          itemBuilder: (context, index) {
                            final blog = data.items[index + 1];
                            return BlogPostCard.fromBlogPostSchema(blog);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              error: (error, _) => ErrorScreen(
                error: error,
                showHomeButton: false,
                onRetry: () => ref.refresh(listBlogPostsProvider.future),
              ),
              loading: LoadingIndicator.new,
            );
          },
        ),
      ),
    );
  }
}
