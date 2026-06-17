import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/features/keeper/repositories/keeper_repository.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';

class WebTotemRouter extends TotemRouter {
  final _navigatorKey = GlobalKey<NavigatorState>();

  Uri get baseUri => Uri.parse(AppConfig.instance.apiUrl);
  // Uri get baseUri => Uri.base;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  GoRouter createRouter(WidgetRef ref) {
    final authController = ref.read(authControllerProvider.notifier);
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authController.authStateChanges),
      observers: [SentryNavigatorObserver()],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _WebRedirectScreen(),
        ),
        GoRoute(
          path: '/:slug',
          builder: (context, state) {
            final container = ProviderScope.containerOf(context);
            final authController = container.read(
              authControllerProvider.notifier,
            );
            final slug = state.pathParameters['slug'] ?? '';

            if (!authController.isAuthenticated) {
              return _WebRedirectScreen(nextRoute: 'room/$slug');
            }

            return SentryDisplayWidget(child: PreJoinScreen(sessionSlug: slug));
          },
        ),
      ],
      errorBuilder: (context, state) => const ErrorScreen(),
    );
  }

  @override
  void popOrHome([BuildContext? context]) {
    if (context != null) {
      if (context.canPop()) {
        context.pop();
        return;
      }
    }

    launchUrlString(baseUri.toString(), webOnlyWindowName: '_self');
  }

  String buildHomeUrl(HomeRoutes route) {
    switch (route) {
      case HomeRoutes.home:
        return baseUri.toString();
      case HomeRoutes.spaces:
        return baseUri.resolve('spaces/').toString();
      case HomeRoutes.blog:
        return baseUri.resolve('blog/').toString();
      case HomeRoutes.profile:
        return baseUri.resolve('users/profile/').toString();
      case HomeRoutes.messages:
        throw UnimplementedError();
    }
  }

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) {
    launchUrlString(buildHomeUrl(route), webOnlyWindowName: '_self');
  }

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {
    final container = ProviderScope.containerOf(context);
    final profile = await container.read(
      keeperProfileProvider(userSlug).future,
    );
    if (profile.username != null) {
      launchUrlString(
        baseUri.resolve('keeper/${profile.username!}/').toString(),
        webOnlyWindowName: '_self',
      );
    }
  }

  @override
  Future<void> toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]) async {
    if (sessionSlug != null) {
      launchUrlString(
        baseUri.resolve('spaces/session/$sessionSlug').toString(),
        webOnlyWindowName: '_self',
      );
    }
  }
}

/// Builds the URI for browser-level redirects.
///
/// When [nextRoute] is provided, returns the login page URL with a `next`
/// query parameter so the parent website can redirect back after login.
/// Otherwise, returns the origin (main website home).
Uri buildRedirectUri({String? nextRoute}) {
  final baseUri = Uri.parse(AppConfig.instance.apiUrl);
  if (nextRoute != null && nextRoute.isNotEmpty) {
    return baseUri
        .resolve('users/login/')
        .replace(queryParameters: {'next': nextRoute});
  }
  return baseUri;
}

class _WebRedirectScreen extends StatefulWidget {
  const _WebRedirectScreen({this.nextRoute});

  /// The route to redirect to after login, if any.
  final String? nextRoute;

  @override
  State<_WebRedirectScreen> createState() => _WebRedirectScreenState();
}

class _WebRedirectScreenState extends State<_WebRedirectScreen> {
  bool _redirected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_redirected) return;
    _redirected = true;
    scheduleMicrotask(_performBrowserRedirect);
  }

  Future<void> _performBrowserRedirect() async {
    final uri = buildRedirectUri(nextRoute: widget.nextRoute);
    await launchUrlString(uri.toString(), webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
