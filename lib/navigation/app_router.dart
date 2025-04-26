import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/controllers/auth_controller.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/pin_entry_screen.dart';
import '../auth/screens/profile_setup_screen.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/spaces/screens/space_detail_screen.dart';
import '../features/spaces/screens/spaces_discovery_screen.dart';
import '../features/video_sessions/screens/pre_join_screen.dart';
import '../features/video_sessions/screens/video_room_screen.dart';
import 'route_names.dart';

class BottomNavScaffold extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const BottomNavScaffold({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
          if (index == 0 && !currentPath.startsWith('/spaces')) {
            context.go('/spaces');
          } else if (index == 1 && !currentPath.startsWith('/profile')) {
            context.go('/profile');
          }
        },
        selectedIndex: currentPath.startsWith('/spaces') ? 0 : 1,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: 'Spaces'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Creates and configures the app router with routes and navigation logic
GoRouter createRouter(WidgetRef ref) {
  // Get the auth controller to check authentication state
  final authController = ref.read(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(
      ref.read(authControllerProvider.notifier).authStateChanges,
    ),
    redirect: (context, state) {
      debugPrint('Router State Change: ${state.fullPath}');
      // Get current auth state
      final isLoggedIn = authController.isAuthenticated;
      final isOnboardingCompleted = authController.isOnboardingCompleted;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      // If we're at the root and logged in, go to spaces
      if (state.matchedLocation == '/' && isLoggedIn) {
        if (!isOnboardingCompleted) {
          return '/onboarding';
        }
        return '/spaces';
      }

      // If we're at the root and not logged in, go to login
      if (state.matchedLocation == '/' && !isLoggedIn) {
        return '/auth/login';
      }

      // If we're trying to access a protected route but not logged in, redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/login';
      }

      // If we're logged in but haven't completed onboarding, and we're not
      // on the onboarding screen, redirect to onboarding
      if (isLoggedIn &&
          !isOnboardingCompleted &&
          !isOnboardingRoute &&
          !isAuthRoute) {
        return '/onboarding';
      }

      // If logged in and trying to access auth routes, redirect to spaces
      if (isLoggedIn && isOnboardingCompleted && isAuthRoute) {
        return '/spaces';
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Auth routes (no bottom nav)
      GoRoute(
        path: '/auth/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/pin',
        name: RouteNames.pinEntry,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return PinEntryScreen(email: email);
        },
      ),
      GoRoute(
        path: '/auth/magic-link',
        name: RouteNames.magicLink,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          // This would typically handle the magic link token
          // and trigger authentication
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),

      // Onboarding (no bottom nav)
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Shell route for screens with bottom navigation
      ShellRoute(
        builder: (context, state, child) {
          return BottomNavScaffold(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          // Spaces tab and its sub-routes with fade transition
          GoRoute(
            path: '/spaces',
            name: RouteNames.spacesDiscovery,
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
              // Nested route under /spaces
              GoRoute(
                path: ':event_slug',
                name: RouteNames.spaceDetail,
                builder: (context, state) {
                  final eventSlug = state.pathParameters['event_slug'] ?? '';
                  return EventDetailScreen(eventSlug: eventSlug);
                },
              ),
            ],
          ),

          // Profile tab with fade transition
          GoRoute(
            path: '/profile',
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

      // Routes that don't show bottom nav
      GoRoute(
        path: '/sessions/:id/pre-join',
        name: RouteNames.preJoinSession,
        builder: (context, state) {
          final sessionId = state.pathParameters['id'] ?? '';
          return PreJoinScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/sessions/:id',
        name: RouteNames.videoSession,
        builder: (context, state) {
          final sessionId = state.pathParameters['id'] ?? '';
          return VideoRoomScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/notifications/settings',
        name: RouteNames.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
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
                    context.go('/spaces');
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
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((dynamic _) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
