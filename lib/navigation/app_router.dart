import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/screens/community_guidelines.dart';
import 'package:totem_app/auth/screens/login_screen.dart';
import 'package:totem_app/auth/screens/onboarding_screen.dart';
import 'package:totem_app/auth/screens/pin_entry_screen.dart';
import 'package:totem_app/auth/screens/profile_setup_screen.dart';
import 'package:totem_app/features/blog/screens/blog_list_screen.dart';
import 'package:totem_app/features/blog/screens/blog_screen.dart';
import 'package:totem_app/features/home/screens/home_screen.dart';
import 'package:totem_app/features/keeper/screens/keeper_profile_screen.dart';
import 'package:totem_app/features/profile/screens/profile_details_screen.dart';
import 'package:totem_app/features/profile/screens/profile_screen.dart';
import 'package:totem_app/features/spaces/screens/session_history.dart';
import 'package:totem_app/features/spaces/screens/space_detail_screen.dart';
import 'package:totem_app/features/spaces/screens/spaces_discovery_screen.dart';
import 'package:totem_app/features/spaces/screens/subcribed_spaces.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:totem_app/shared/offline_indicator.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';

enum HomeRoutes {
  home(RouteNames.home),
  spaces(RouteNames.spaces),
  blog(RouteNames.blog),
  profile(RouteNames.profile);

  const HomeRoutes(this.path);

  final String path;

  static const HomeRoutes initialRoute = HomeRoutes.home;
}

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
    final currentRoute = HomeRoutes.values.firstWhere(
      (route) => currentPath.startsWith(route.path),
      orElse: () => HomeRoutes.initialRoute,
    );

    return Scaffold(
      body: OfflineIndicatorPage(child: child),

      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: NavigationBar(
          onDestinationSelected: (index) {
            for (final route in HomeRoutes.values) {
              logger.i('🛻 Checking route: ${route.path}');
              if (index == route.index && currentRoute != route) {
                logger.i('🛻 Navigating to: ${route.path}');
                context.go(route.path);
                return;
              }
            }
          },
          selectedIndex: currentRoute.index,
          destinations: const [
            NavigationDestination(
              icon: TotemIcon(TotemIcons.home),
              selectedIcon: TotemIcon(TotemIcons.homeFilled, fillColor: false),
              label: 'Home',
            ),
            NavigationDestination(
              icon: TotemIcon(TotemIcons.spaces),
              selectedIcon: TotemIcon(
                TotemIcons.spacesFilled,
                fillColor: false,
              ),
              label: 'Spaces',
            ),
            NavigationDestination(
              icon: TotemIcon(TotemIcons.blog),
              selectedIcon: TotemIcon(TotemIcons.blogFilled, fillColor: false),
              label: 'Blog',
            ),
            NavigationDestination(
              icon: TotemIcon(TotemIcons.profile),
              selectedIcon: TotemIcon(
                TotemIcons.profileFilled,
                fillColor: false,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

void popOrHome([BuildContext? context]) {
  if (context != null) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.pushReplacementNamed(RouteNames.welcome);
    }
  } else if (navigatorKey.currentState?.canPop() ?? false) {
    navigatorKey.currentState?.pop();
  } else {
    navigatorKey.currentState?.pushReplacementNamed(RouteNames.welcome);
  }
}

final shellNavigatorKey = GlobalKey<StatefulNavigationShellState>();
void toHome(HomeRoutes route) {
  if (shellNavigatorKey.currentState != null) {
    shellNavigatorKey.currentState?.goBranch(route.index);
  } else {
    navigatorKey.currentState?.pushReplacementNamed(RouteNames.welcome);
  }
}

final navigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(WidgetRef ref) {
  final authController = ref.read(authControllerProvider.notifier);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authController.authStateChanges),
    observers: [PosthogObserver()],
    redirect: (context, state) async {
      logger.i('🛻 Router State Change: ${state.fullPath}');

      // Get current auth state
      final isRoot = state.matchedLocation == '/';
      final isLoggedIn = authController.isAuthenticated;
      final isOnboardingCompleted = authController.isOnboardingCompleted;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnboardingRoute = state.matchedLocation == RouteNames.onboarding;
      final isWelcomeRoute = state.matchedLocation == RouteNames.welcome;

      // Check if user has seen welcome onboarding (first-time user detection)
      final hasSeenWelcomeOnboarding =
          await authController.hasSeenWelcomeOnboarding;

      // If we're at the root
      if (isRoot) {
        if (isLoggedIn) {
          // User is logged in
          if (!isOnboardingCompleted) {
            logger.i('🛻 Redirecting logged-in user to profile onboarding');
            return RouteNames.communityGuidelines;
          }
          logger.i('🛻 Redirecting logged-in user to spaces');
          return RouteNames.spaces;
        } else {
          // User is not logged in
          if (!hasSeenWelcomeOnboarding) {
            logger.i('🛻 First-time user - staying on welcome screens');
            return null; // Stay on welcome screens
          } else {
            logger.i('🛻 Returning user - redirecting to login');
            return RouteNames.login;
          }
        }
      }

      // If trying to access welcome screens but already seen them
      if (isWelcomeRoute && hasSeenWelcomeOnboarding && !isLoggedIn) {
        logger.i('🛻 User already seen welcome - redirecting to login');
        return RouteNames.login;
      }

      if (isAuthRoute && isLoggedIn) {
        // If we're logged in and trying to access auth routes, redirect to
        // home
        logger.i('🛻 Redirecting to home from auth route');
        return HomeRoutes.initialRoute.path;
      }

      // If we're trying to access a protected route but not logged in, redirect
      // to login
      if (!isLoggedIn && !isAuthRoute && !isRoot && !isWelcomeRoute) {
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

      // If logged in and trying to access auth routes, redirect to home
      if (isLoggedIn && isOnboardingCompleted && isAuthRoute) {
        logger.i('🛻 Redirecting to home from auth route');
        return HomeRoutes.initialRoute.path;
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.welcome,
        name: RouteNames.welcome,
        builder: (context, state) => const OnboardingScreen(),
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
        path: RouteNames.communityGuidelines,
        name: RouteNames.communityGuidelines,
        builder: (context, state) => const CommunityGuidelinesScreen(),
      ),
      // Onboarding (no bottom nav)
      GoRoute(
        path: RouteNames.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Shell route for screens with bottom navigation
      StatefulShellRoute.indexedStack(
        key: shellNavigatorKey,
        parentNavigatorKey: navigatorKey,
        builder: (context, state, child) {
          return HeroControllerScope(
            controller: MaterialApp.createMaterialHeroController(),
            child: BottomNavScaffold(
              currentPath: state.matchedLocation,
              child: child,
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.home,
                name: RouteNames.home,
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                  transitionsBuilder:
                      (
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

          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.spaces,
                name: RouteNames.spaces,
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const SpacesDiscoveryScreen(),
                  transitionsBuilder:
                      (
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

          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.blog,
                name: RouteNames.blog,
                builder: (context, state) => const BlogListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profile,
                name: RouteNames.profile,
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                  transitionsBuilder:
                      (
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
                    path: RouteNames.profileDetail,
                    name: RouteNames.profileDetail,
                    builder: (context, state) => const ProfileDetailsScreen(),
                  ),
                  GoRoute(
                    path: RouteNames.subscribedSpaces,
                    name: RouteNames.subscribedSpaces,
                    builder: (context, state) => const SubscribedSpacesScreen(),
                  ),
                  GoRoute(
                    path: RouteNames.sessionHistory,
                    name: RouteNames.sessionHistory,
                    builder: (context, state) => const SessionHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: RouteNames.space(':event_slug'),
        name: RouteNames.space(':event_slug'),
        builder: (context, state) {
          final eventSlug = state.pathParameters['event_slug'] ?? '';
          return EventDetailScreen(eventSlug: eventSlug);
        },
      ),

      GoRoute(
        path: RouteNames.keeperProfile(':slug'),
        name: RouteNames.keeperProfile(':slug'),
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return KeeperProfileScreen(slug: slug);
        },
      ),

      GoRoute(
        path: RouteNames.blogPost(':slug'),
        name: RouteNames.blogPost(':slug'),
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return BlogScreen(slug: slug);
        },
      ),

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
    errorBuilder: (context, state) => const ErrorScreen(),
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
