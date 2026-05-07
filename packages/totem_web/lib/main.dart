import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/auth/screens/login_screen.dart';
import 'package:totem_app/features/auth/screens/pin_entry_screen.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared_main.dart';

void main() {
  sharedMain(const TotemWebApp());
}

class TotemWebApp extends ConsumerWidget {
  const TotemWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authController = ref.read(authControllerProvider.notifier);

    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authController.authStateChanges),
      redirect: (context, state) {
        final isLoggedIn = authController.isAuthenticated;
        final isLoginRoute = state.matchedLocation == RouteNames.login;
        final isPinRoute = state.matchedLocation == RouteNames.pinEntry;
        final isSessionRoute = state.matchedLocation.startsWith('/session/');

        // TODO(web): Better way to handle redirect

        if (!isLoggedIn && isSessionRoute) {
          return '${RouteNames.login}?next=${Uri.encodeComponent(state.uri.toString())}';
        }

        if (isLoggedIn && isLoginRoute) {
          final nextRoute = state.uri.queryParameters['next'];
          if (nextRoute != null && nextRoute.isNotEmpty) {
            return nextRoute;
          }

          return '/';
        }

        if (isLoggedIn && isPinRoute) {
          final nextRoute = state.uri.queryParameters['next'];
          if (nextRoute != null && nextRoute.isNotEmpty) {
            return nextRoute;
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text(
                'Open a session URL, for example: /session/my-session',
              ),
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) {
            final nextRoute = state.uri.queryParameters['next'];
            return LoginScreen(nextRoute: nextRoute);
          },
        ),
        GoRoute(
          path: RouteNames.pinEntry,
          builder: (context, state) {
            final email =
                state.uri.queryParameters['email'] ??
                ((state.extra as Map?)?['email'] as String? ?? '');
            final nextRoute =
                state.uri.queryParameters['next'] ??
                ((state.extra as Map?)?['nextRoute'] as String?);
            return PinEntryScreen(email: email, nextRoute: nextRoute);
          },
        ),
        GoRoute(
          path: RouteNames.session(':slug'),
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return PreJoinScreen(sessionSlug: slug);
          },
        ),
      ],
      errorBuilder: (context, state) =>
          const Scaffold(body: Center(child: Text('Page not found'))),
    );

    return MaterialApp.router(
      routerConfig: router,
      title: 'Totem',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.5,
          child: child!,
        );
      },
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((dynamic _) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
