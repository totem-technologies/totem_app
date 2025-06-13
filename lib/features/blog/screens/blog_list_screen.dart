import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/widgets/blog_card.dart';

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogs = ref.watch(listBlogPostsProvider);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return blogs.when<Widget>(
            data: (data) {
              if (data.items.isEmpty) {
                return const Center(child: Text('No blog posts available'));
              }

              return CustomScrollView(
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
                        height: constraints.maxHeight * 0.45,
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
              );
            },
            error: (error, stackTrace) {
              return Center(child: Text('Error loading blogs: $error'));
            },
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
          );
        },
      ),
    );
  }
}
