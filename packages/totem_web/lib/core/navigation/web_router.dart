import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/features/keeper/repositories/keeper_repository.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';

class WebTotemRouter extends TotemRouter {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  GoRouter createRouter(WidgetRef ref) {
    final authController = ref.read(authControllerProvider.notifier);
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authController.authStateChanges),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final nextRoute = state.uri.queryParameters['next'];
            return _WebRedirectScreen(nextRoute: nextRoute);
          },
        ),
        GoRoute(
          path: '/:slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return PreJoinScreen(sessionSlug: slug);
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

    launchUrlString('https://www.totem.org/', webOnlyWindowName: '_self');
  }

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) {
    switch (route) {
      case HomeRoutes.home:
        launchUrlString('https://www.totem.org/', webOnlyWindowName: '_self');
        break;
      case HomeRoutes.spaces:
        launchUrlString(
          'https://www.totem.org/spaces/',
          webOnlyWindowName: '_self',
        );
        break;
      case HomeRoutes.blog:
        launchUrlString(
          'https://www.totem.org/blog/',
          webOnlyWindowName: '_self',
        );
        break;
      case HomeRoutes.profile:
        launchUrlString(
          'https://www.totem.org/users/profile/',
          webOnlyWindowName: '_self',
        );
        break;
    }
  }

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {
    final container = ProviderScope.containerOf(context);
    final profile = await container.read(
      keeperProfileProvider(userSlug).future,
    );
    if (profile.username != null) {
      launchUrlString(
        'https://www.totem.org/keeper/${profile.username!}/',
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
        'https://www.totem.org/spaces/session/$sessionSlug',
        webOnlyWindowName: '_self',
      );
    }
  }
}

class _WebRedirectScreen extends StatefulWidget {
  const _WebRedirectScreen({this.nextRoute});

  final String? nextRoute;

  @override
  State<_WebRedirectScreen> createState() => _WebRedirectScreenState();
}

class _WebRedirectScreenState extends State<_WebRedirectScreen> {
  bool _redirected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_redirected) {
      return;
    }
    _redirected = true;
    scheduleMicrotask(_redirectToSignIn);
  }

  Future<void> _redirectToSignIn() async {
    final baseUri = Uri.parse(AppConfig.instance.apiUrl);
    final nextRoute = widget.nextRoute;
    final signInUri = baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        if (nextRoute != null && nextRoute.isNotEmpty) 'next': nextRoute,
      },
    );

    await launchUrlString(signInUri.toString(), webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
