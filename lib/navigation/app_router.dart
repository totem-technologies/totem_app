import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/controllers/auth_controller.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/pin_entry_screen.dart';
import '../auth/screens/profile_setup_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/spaces/screens/spaces_discovery_screen.dart';
import '../features/spaces/screens/space_detail_screen.dart';
import '../features/video_sessions/screens/pre_join_screen.dart';
import '../features/video_sessions/screens/video_room_screen.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import 'route_names.dart';

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
      debugPrint("Router State Change: $state");
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
      if (isLoggedIn && !isOnboardingCompleted && !isOnboardingRoute) {
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
      // Auth routes
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
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Main app routes
      GoRoute(
        path: '/spaces',
        name: RouteNames.spacesDiscovery,
        builder: (context, state) => const SpacesDiscoveryScreen(),
      ),
      GoRoute(
        path: '/spaces/:id',
        name: RouteNames.spaceDetail,
        builder: (context, state) {
          final spaceId = state.pathParameters['id'] ?? '';
          return SpaceDetailScreen(spaceId: spaceId);
        },
      ),
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
        path: '/profile',
        name: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
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
