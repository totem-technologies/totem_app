import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/widgets/blog_post_card.dart';
import 'package:totem_app/features/blog/widgets/featured_blog_post.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogs = ref.watch(listBlogPostsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(listBlogPostsProvider.future),
      child: blogs.when(
        data: (data) {
          if (data.items.isEmpty) {
            return const Center(child: Text('No blog posts available'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topEnd,
                    end: AlignmentDirectional.bottomStart,
                    stops: [0.6, 1],
                    colors: [
                      Color(0xffFCEFE4),
                      Color(0xff435DD0),
                    ],
                  ),
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: FeaturedBlogPost.fromBlogPostSchema(
                        data.items.first,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.only(top: 20),
                      sliver: SliverFixedExtentList.builder(
                        itemExtent: NewBlogPostCard.cardHeight + 20,
                        itemCount: data.items.sublist(1).length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: 20),
                          child: NewBlogPostCard.fromBlogPostSchema(
                            data.items[index + 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
      ),
    );
  }
}
