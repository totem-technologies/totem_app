import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/screens/blog_list_screen.dart';
import 'package:totem_app/features/blog/screens/blog_screen.dart';
import 'package:totem_app/features/blog/widgets/featured_blog_post.dart';
import 'package:totem_core/shared/widgets/empty_indicator.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/shared/router.dart';

final class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> logout() async {}

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  UserSchema? get user => null;
}

final class _TestRouter extends TotemRouter {
  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Uri get baseUri => Uri.parse('https://test.example.com/');

  @override
  void popOrHome([BuildContext? context]) => context?.pop();

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) {}

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {}

  @override
  Future<void> toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]) async {}

  @override
  GoRouter createRouter(WidgetRef ref) => throw UnsupportedError('test');

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {}
}

BlogPostListSchema _post(String slug, String title) =>
    BlogPostListSchema(slug: slug, title: title, publish: true, readTime: 3);

BlogPostSchema _detail(String slug) => BlogPostSchema(
  slug: slug,
  title: 'A detailed post',
  contentHtml: '<p>Useful content</p>',
  publish: true,
  readTime: 4,
);

void main() {
  testWidgets('blog list exposes its empty state and retries successfully', (
    tester,
  ) async {
    var loads = 0;
    final posts = PagedBlogPostListSchema(
      items: [_post('recovered', 'Recovered post')],
      count: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listBlogPostsProvider.overrideWith((_) async {
            loads++;
            return loads == 1
                ? const PagedBlogPostListSchema(items: [], count: 0)
                : posts;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: BlogListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    check(tester.widgetList(find.byType(EmptyIndicator))).length.equals(1);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    check(loads).equals(2);
    check(tester.widgetList(find.byType(FeaturedBlogPost))).length.equals(1);
  });

  testWidgets('blog list shows an error and recovers through retry', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listBlogPostsProvider.overrideWith((_) async {
            loads++;
            if (loads == 1) throw StateError('temporary failure');
            return PagedBlogPostListSchema(
              items: [_post('recovered', 'Recovered post')],
              count: 1,
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: BlogListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    check(tester.widgetList(find.byType(ErrorScreen))).length.equals(1);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    check(loads).equals(2);
    check(tester.widgetList(find.byType(FeaturedBlogPost))).length.equals(1);
  });

  testWidgets('blog navigation opens detail and back returns to the list', (
    tester,
  ) async {
    TotemRouter.instance = _TestRouter();
    final router = GoRouter(
      initialLocation: '/blog',
      routes: [
        GoRoute(
          path: '/blog',
          builder: (_, _) => const Scaffold(body: BlogListScreen()),
        ),
        GoRoute(
          path: '/blog/:slug',
          builder: (_, state) =>
              BlogScreen(slug: state.pathParameters['slug']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          listBlogPostsProvider.overrideWith(
            (_) async => PagedBlogPostListSchema(
              items: [_post('post-slug', 'A blog post')],
              count: 1,
            ),
          ),
          blogPostProvider(
            'post-slug',
          ).overrideWith((_) async => _detail('post-slug')),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    check(tester.widgetList(find.text('A detailed post'))).length.equals(1);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    check(tester.widgetList(find.byType(FeaturedBlogPost))).length.equals(1);
  });
}
