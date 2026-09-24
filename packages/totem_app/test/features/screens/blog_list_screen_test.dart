import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/screens/blog_list_screen.dart';
import 'package:totem_app/features/blog/widgets/featured_blog_post.dart';
import 'package:totem_app/features/home/widgets/home_blog_card.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/shared/assets.dart';

import '../../../../totem_core/test/auth/controllers/auth_controller_mock.dart';

void main() {
  group('BlogListScreen', () {
    testWidgets('renders featured blog post and blog post cards correctly', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await const AssetImage(
          TotemImageAssets.genericBackground,
          package: 'totem_core',
        ).evict();
        tester.binding.imageCache.clearLiveImages();
        tester.binding.imageCache.clear();
      });

      final blog1 = BlogPostListSchema(
        title: 'Featured Blog Post',
        slug: Omittable('featured-post'),
        datePublished: DateTime.now(),
        readTime: 5,
        publish: true,
      );

      final blog2 = BlogPostListSchema(
        title: 'Second Blog Post',
        slug: Omittable('second-post'),
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
      check(tester.widgetList(find.byType(FeaturedBlogPost))).length.equals(1);
      check(
        tester.widgetList(find.text('Featured Blog Post')),
      ).length.isGreaterThan(0);

      // Check if HomeBlogCard is rendered for the subsequent items
      check(tester.widgetList(find.byType(HomeBlogCard))).length.equals(1);
      check(
        tester.widgetList(find.text('Second Blog Post')),
      ).length.isGreaterThan(0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await const AssetImage(
        TotemImageAssets.genericBackground,
        package: 'totem_core',
      ).evict();
      tester.binding.imageCache.clearLiveImages();
      tester.binding.imageCache.clear();
    });
  });
}
