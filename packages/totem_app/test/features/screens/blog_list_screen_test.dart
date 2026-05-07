import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/screens/blog_list_screen.dart';
import 'package:totem_app/features/blog/widgets/featured_blog_post.dart';
import 'package:totem_app/features/home/widgets/home_blog_card.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

import '../../../../totem_core/test/auth/controllers/auth_controller_mock.dart';

void main() {
  group('BlogListScreen', () {
    testWidgets('renders featured blog post and blog post cards correctly', (
      tester,
    ) async {
      final blog1 = BlogPostListSchema(
        title: 'Featured Blog Post',
        slug: 'featured-post',
        datePublished: DateTime.now(),
        readTime: 5,
        publish: true,
      );

      final blog2 = BlogPostListSchema(
        title: 'Second Blog Post',
        slug: 'second-post',
        datePublished: DateTime.now(),
        readTime: 3,
        publish: true,
      );

      final mockData = PagedBlogPostListSchema(items: [blog1, blog2], count: 2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(AuthState.unauthenticated()),
            ),
            listBlogPostsProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: Scaffold(body: BlogListScreen())),
        ),
      );

      // Settle loading states
      await tester.pump();

      // Check if FeaturedBlogPost is rendered for the first item
      expect(find.byType(FeaturedBlogPost), findsOneWidget);
      expect(find.text('Featured Blog Post'), findsWidgets);

      // Check if HomeBlogCard is rendered for the subsequent items
      expect(find.byType(HomeBlogCard), findsOneWidget);
      expect(find.text('Second Blog Post'), findsWidgets);
    });
  });
}
