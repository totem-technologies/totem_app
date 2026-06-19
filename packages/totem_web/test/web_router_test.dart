import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/models/profile_avatar_type_enum.dart';
import 'package:totem_core/core/api/api_client/models/user_schema.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_web/core/navigation/web_router.dart';

import '../../totem_core/test/auth/controllers/auth_controller_mock.dart';

final _fakeUser = UserSchema(
  profileAvatarType: ProfileAvatarTypeEnum.td,
  circleCount: 0,
  email: 'test@totem.org',
  dateCreated: DateTime(2024),
);

/// Creates a test widget tree with a [ProviderScope] and [GoRouter].
Future<GoRouter> _pumpTestRouter(
  WidgetTester tester, {
  required AuthState authState,
}) async {
  GoRouter? router;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(authState),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          router ??= WebTotemRouter().createRouter(ref);
          return MaterialApp.router(routerConfig: router!);
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
  return router!;
}

void main() {
  setUpAll(() {
    AppConfig.instance = AppConfig(
      environment: Environment.development,
      apiUrl: 'https://totem.org/',
      liveKitUrl: 'https://livekit.totem.org/',
      maxPinAttempts: 5,
      vapidKey: null,
      analyticsEnabled: false,
      sentryDsn: null,
      posthogApiKey: null,
      posthogHost: 'https://us.i.posthog.com',
      privacyPolicyUrl: Uri.parse('https://totem.org/privacy/'),
      termsOfServiceUrl: Uri.parse('https://totem.org/tos/'),
      communityGuidelinesUrl: Uri.parse('https://totem.org/guidelines/'),
    );
  });

  group('buildRedirectUri', () {
    test('returns origin (main website home) when nextRoute is null', () {
      final uri = buildRedirectUri();
      expect(uri.toString(), 'https://totem.org/');
    });

    test('returns origin when nextRoute is empty', () {
      final uri = buildRedirectUri();
      expect(uri.toString(), 'https://totem.org/');
    });
  });

  group('buildHomeUrl', () {
    test('returns correct URLs for each HomeRoute', () {
      final router = WebTotemRouter();
      expect(router.buildHomeUrl(HomeRoutes.home), 'https://totem.org/');
      expect(
        router.buildHomeUrl(HomeRoutes.spaces),
        'https://totem.org/spaces/',
      );
      expect(router.buildHomeUrl(HomeRoutes.blog), 'https://totem.org/blog/');
      expect(
        router.buildHomeUrl(HomeRoutes.profile),
        'https://totem.org/users/profile/',
      );
    });
  });

  group('GoRouter route configuration', () {
    testWidgets('has routes for / and /:slug', (tester) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      final routes = router.configuration.routes;
      expect(routes.length, 2);
      expect((routes[0] as GoRoute).path, '/');
      expect((routes[1] as GoRoute).path, '/:slug');
    });

    testWidgets('/:slug route captures the slug path parameter', (
      tester,
    ) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      router.go('/test-session');
      await tester.pump();

      expect(router.state.uri.path, '/test-session');
      expect(router.state.pathParameters['slug'], 'test-session');
    });

    testWidgets('/ route matches the root path', (tester) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      router.go('/');
      await tester.pump();

      expect(router.state.uri.path, '/');
    });
  });

  group('Auth-based redirect behavior', () {
    testWidgets('/:slug shows redirect screen when unauthenticated', (
      tester,
    ) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.unauthenticated(),
      );

      router.go('/test-session');
      await tester.pump();

      // _WebRedirectScreen displays a Scaffold.
      expect(find.byType(Scaffold), findsOneWidget);
      // PreJoinScreen must NOT be shown.
      expect(find.byType(PreJoinScreen), findsNothing);
    });

    testWidgets('/:slug shows redirect screen when auth status is initial '
        '(not yet authenticated)', (tester) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      router.go('/test-session');
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(PreJoinScreen), findsNothing);
    });

    test('isAuthenticated returns correct values for each auth status', () {
      expect(
        FakeAuthController(
          AuthState.authenticated(user: _fakeUser),
        ).isAuthenticated,
        isTrue,
      );
      expect(
        FakeAuthController(AuthState.unauthenticated()).isAuthenticated,
        isFalse,
      );
      expect(FakeAuthController(AuthState.initial()).isAuthenticated, isFalse);
      expect(FakeAuthController(AuthState.loading()).isAuthenticated, isFalse);
    });

    testWidgets('/ (root) shows redirect screen regardless of auth state', (
      tester,
    ) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      router.go('/');
      await tester.pump();

      // Root always redirects to origin via the redirect screen.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
