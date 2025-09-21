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
    return blogs.when(
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
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: [0.6, 1],
                  colors: [
                    Color(0xffFCEFE4),
                    Color(0xff435DD0),
                  ],
                ),
              ),
              child: ListView(
                padding: EdgeInsetsDirectional.zero,
                children: [
                  FeaturedBlogPost.fromBlogPostSchema(data.items.first),
                  const SizedBox(height: 20),
                  ...List.generate(
                    data.items.sublist(1).length,
                    (index) => NewBlogPostCard.fromBlogPostSchema(
                      data.items[index + 1],
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
    );
  }
}
