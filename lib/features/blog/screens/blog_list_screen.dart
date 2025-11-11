import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/layout/layout.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/widgets/blog_post_card.dart';
import 'package:totem_app/features/blog/widgets/featured_blog_post.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogs = ref.watch(listBlogPostsProvider);
    return ResponsiveLayoutManager(
      builder: (context, layoutInfo) {
        final verticalPadding = layoutInfo.verticalPadding;
        final spacing = layoutInfo.gridSpacing;

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

              final showGrid = layoutInfo.isTablet || layoutInfo.isDesktop;
              final remainingPosts = data.items.sublist(1);

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
                        if (showGrid)
                          SliverPadding(
                            padding: EdgeInsetsDirectional.only(
                              start: layoutInfo.horizontalPadding,
                              end: layoutInfo.horizontalPadding,
                              top: verticalPadding,
                              bottom:
                                  BottomNavScaffold.bottomNavHeight +
                                  verticalPadding,
                            ),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: layoutInfo.gridColumns,
                                    childAspectRatio: 16 / 21,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                  ),
                              itemCount: remainingPosts.length,
                              itemBuilder: (context, index) =>
                                  BlogPostCard.fromBlogPostSchema(
                                    remainingPosts[index],
                                  ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsetsDirectional.only(
                              top: verticalPadding,
                              bottom:
                                  BottomNavScaffold.bottomNavHeight +
                                  verticalPadding,
                              start: layoutInfo.horizontalPadding,
                              end: layoutInfo.horizontalPadding,
                            ),
                            sliver: SliverFixedExtentList.builder(
                              itemExtent: BlogPostCard.cardHeight + spacing,
                              itemCount: remainingPosts.length,
                              itemBuilder: (context, index) => Padding(
                                padding: EdgeInsetsDirectional.only(
                                  bottom: spacing,
                                ),
                                child: BlogPostCard.fromBlogPostSchema(
                                  remainingPosts[index],
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
      },
    );
  }
}
