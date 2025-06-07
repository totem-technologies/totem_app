import 'package:flutter/material.dart';
import 'package:totem_app/features/blog/widgets/blog_card.dart';

class BlogListScreen extends StatelessWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
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
                    child: BlogPostCard(
                      title:
                          "Unhealthy Boundaries in Relationships: 9 Signs it's Affecting Your Mental Health",
                      authorName: 'Maria',
                      authorImageUrl: null,
                      authorImageSeed: '00,00,00',
                      publishedDate: DateTime.now(),
                      image:
                          'https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=800&q=60',
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 12 / 16,
                  ),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return BlogPostCard(
                      title:
                          "Unhealthy Boundaries in Relationships: 9 Signs it's Affecting Your Mental Health",
                      authorName: 'Maria',
                      authorImageUrl: null,
                      authorImageSeed: '00,00,00',
                      publishedDate: DateTime.now(),
                      image:
                          'https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=800&q=60',
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
