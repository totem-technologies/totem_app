import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/widgets/blog_post_card.dart';
import 'package:totem_app/features/blog/widgets/featured_blog_post.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogs = ref.watch(listBlogPostsProvider);
    ref.sentryReportFullyDisplayed(listBlogPostsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(listBlogPostsProvider.future),
      child: blogs.when(
        data: (data) {
          if (data.items.isEmpty) {
            return EmptyIndicator(
              icon: TotemIcons.blog,
              text: 'No blog posts available yet',
              onRetry: () => ref.refresh(listBlogPostsProvider.future),
            );
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
                    SliverSafeArea(
                      top: false,
                      sliver: SliverPadding(
                        padding: const EdgeInsetsDirectional.only(
                          top: 20,
                          bottom: 20,
                        ),
                        sliver: SliverFixedExtentList.builder(
                          itemExtent: BlogPostCard.cardHeight + 10,
                          itemCount: data.items.sublist(1).length,
                          itemBuilder: (context, index) =>
                              BlogPostCard.fromBlogPostSchema(
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
