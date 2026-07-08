import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/features/keeper/repositories/keeper_repository.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web;

class WebTotemRouter extends TotemRouter {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Uri get baseUri {
    final scheme = Uri.base.scheme;
    final host = Uri.base.host;
    return Uri(scheme: scheme, host: host, path: '/');
  }

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
            final slug = state.pathParameters['slug'] ?? '';
            return SentryDisplayWidget(child: PreJoinScreen(sessionSlug: slug));
          },
        ),
      ],
      errorBuilder: (context, state) => const ErrorScreen(),
    );
  }

  static void _beforeUnloadListener(web.Event event) {
    final beforeUnloadEvent = event as web.BeforeUnloadEvent;
    beforeUnloadEvent.returnValue = 'Are you sure you want to leave?';
  }

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {
    if (enabled) {
      web.window.onbeforeunload = _beforeUnloadListener.toJS;
    } else {
      web.window.onbeforeunload = null;
    }
  }

  @override
  void popOrHome([BuildContext? context]) {
    if (context != null) {
      if (context.canPop()) {
        context.pop();
        return;
      }
    }

    toHome();
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

class _WebRedirectScreen extends StatefulWidget {
  const _WebRedirectScreen();

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
    final uri = TotemRouter.instance.baseUri;
    await launchUrlString(uri.toString(), webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
