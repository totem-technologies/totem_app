import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/screens/login_screen.dart';
import 'package:totem_app/auth/screens/pin_entry_screen.dart';
import 'package:totem_app/auth/screens/profile_setup_screen.dart';
import 'package:totem_app/auth/screens/welcome_screen.dart';
import 'package:totem_app/features/profile/screens/profile_screen.dart';
import 'package:totem_app/features/spaces/screens/space_detail_screen.dart';
import 'package:totem_app/features/spaces/screens/spaces_discovery_screen.dart';
import 'package:totem_app/main.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:totem_app/shared/svg_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class BottomNavScaffold extends StatelessWidget {
  const BottomNavScaffold({
    required this.child,
    required this.currentPath,
    super.key,
  });
  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,

      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
          if (index == 0 && !currentPath.startsWith('/spaces')) {
            context.go(RouteNames.spaces);
          } else if (index == 1 && !currentPath.startsWith('/profile')) {
            context.go(RouteNames.profile);
          }
        },
        selectedIndex: currentPath.startsWith('/spaces') ? 0 : 1,
        destinations: const [
          NavigationDestination(
            icon: TotemIcon(TotemIcons.home),
            label: 'Spaces',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

GoRouter createRouter(WidgetRef ref) {
  final authController = ref.read(authControllerProvider.notifier);

  return GoRouter(
    navigatorKey: TotemApp.navigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authController.authStateChanges),
    observers: [PosthogObserver()],
    redirect: (context, state) {
      logger.i('🛻 Router State Change: ${state.fullPath}');

      // Get current auth state
      final isRoot = state.matchedLocation == '/';
      final isLoggedIn = authController.isAuthenticated;
      final isOnboardingCompleted = authController.isOnboardingCompleted;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnboardingRoute = state.matchedLocation == RouteNames.onboarding;

      // If we're at the root and logged in, go to spaces
      if (isRoot && isLoggedIn) {
        if (!isOnboardingCompleted) {
          logger.i('🛻 Redirecting to onboarding');
          return RouteNames.onboarding;
        }
        logger.i('🛻 Redirecting to spaces');
        return RouteNames.spaces;
      }

      // If we're at the root and not logged in, go to login
      // if (state.matchedLocation == '/' && !isLoggedIn) {
      //   return RouteNames.login;
      // }

      if (isAuthRoute && isLoggedIn) {
        // If we're logged in and trying to access auth routes, redirect to
        // spaces
        logger.i('🛻 Redirecting to spaces from auth route');
        return RouteNames.spaces;
      }

      // If we're trying to access a protected route but not logged in, redirect
      // to login
      if (!isLoggedIn && !isAuthRoute && !isRoot) {
        logger.i('🛻 Redirecting to login from non-auth route');
        return RouteNames.login;
      }

      // If we're logged in but haven't completed onboarding, and we're not
      // on the onboarding screen, redirect to onboarding
      if (isLoggedIn &&
          !isOnboardingCompleted &&
          !isOnboardingRoute &&
          !isAuthRoute) {
        logger.i('🛻 Redirecting to onboarding from non-onboarding route');
        return RouteNames.onboarding;
      }

      // If logged in and trying to access auth routes, redirect to spaces
      if (isLoggedIn && isOnboardingCompleted && isAuthRoute) {
        logger.i('🛻 Redirecting to spaces from auth route');
        return RouteNames.spaces;
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.welcome,
        name: RouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      // Auth routes (no bottom nav)
      GoRoute(
        path: RouteNames.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.pinEntry,
        name: RouteNames.pinEntry,
        builder: (context, state) {
          final String email =
              (state.uri.queryParameters['email']) ??
              ((state.extra as Map?)?['email'] as String?) ??
              '';
          return PinEntryScreen(email: email);
        },
      ),
      GoRoute(
        path: RouteNames.magicLink,
        name: RouteNames.magicLink,
        builder: (context, state) {
          // TODO(auth): Handle magic link token
          // final token = state.uri.queryParameters['token'] ?? '';
          // This would typically handle the magic link token
          // and trigger authentication
          return const Scaffold(body: LoadingIndicator());
        },
      ),

      // Onboarding (no bottom nav)
      GoRoute(
        path: RouteNames.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Shell route for screens with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) {
          return BottomNavScaffold(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        branches: [
          // Spaces tab and its sub-routes with fade transition
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.spaces,
                name: RouteNames.spaces,
                pageBuilder:
                    (context, state) => CustomTransitionPage(
                      key: state.pageKey,
                      child: const SpacesDiscoveryScreen(),
                      transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 200),
                    ),
                routes: [
                  GoRoute(
                    path: ':event_slug',
                    name: RouteNames.spaceDetail,
                    builder: (context, state) {
                      final eventSlug =
                          state.pathParameters['event_slug'] ?? '';
                      return EventDetailScreen(eventSlug: eventSlug);
                    },
                  ),
                ],
              ),
            ],
          ),

          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profile,
                name: RouteNames.profile,
                pageBuilder:
                    (context, state) => CustomTransitionPage(
                      key: state.pageKey,
                      child: const ProfileScreen(),
                      transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 200),
                    ),
              ),
            ],
          ),
        ],
      ),

      // Routes that don't show bottom nav
      // GoRoute(
      //   path: '/sessions/:id/pre-join',
      //   name: RouteNames.preJoinSession,
      //   builder: (context, state) {
      //     final sessionId = state.pathParameters['id'] ?? '';
      //     return PreJoinScreen(sessionId: sessionId);
      //   },
      // ),
      // GoRoute(
      //   path: '/sessions/:id',
      //   name: RouteNames.videoSession,
      //   builder: (context, state) {
      //     final sessionId = state.pathParameters['id'] ?? '';
      //     return VideoRoomScreen(sessionId: sessionId);
      //   },
      // ),
      // GoRoute(
      //   path: '/notifications/settings',
      //   name: RouteNames.notificationSettings,
      //   builder: (context, state) => const NotificationSettingsScreen(),
      // ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Oops! Something went wrong.',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    context.go(RouteNames.spaces);
                  },
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
  );
}

/// A class to wrap a Stream as a Listenable for GoRouter refreshes
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
