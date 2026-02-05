import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/screens/login_screen.dart';
import 'package:totem_app/auth/screens/onboarding_screen.dart';
import 'package:totem_app/auth/screens/pin_entry_screen.dart';
import 'package:totem_app/auth/screens/profile_setup_screen.dart';
import 'package:totem_app/features/blog/screens/blog_list_screen.dart';
import 'package:totem_app/features/blog/screens/blog_screen.dart';
import 'package:totem_app/features/home/screens/home_screen.dart';
import 'package:totem_app/features/home/widgets/join_ongoing_session_card.dart';
import 'package:totem_app/features/keeper/screens/keeper_profile_screen.dart';
import 'package:totem_app/features/profile/screens/profile_details_screen.dart';
import 'package:totem_app/features/profile/screens/profile_screen.dart';
import 'package:totem_app/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_app/features/spaces/screens/session_history.dart';
import 'package:totem_app/features/spaces/screens/space_detail_screen.dart';
import 'package:totem_app/features/spaces/screens/spaces_discovery_screen.dart';
import 'package:totem_app/features/spaces/screens/subcribed_spaces.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/offline_indicator.dart';

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

  static const double bottomNavHeight = 80;

  @override
  Widget build(BuildContext context) {
    final currentRoute = HomeRoutes.values.firstWhere(
      (route) => currentPath.startsWith(route.path),
      orElse: () => HomeRoutes.initialRoute,
    );

    return Scaffold(
      body: OfflineIndicatorPage(child: child),
      extendBody: true,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const JoinOngoingSessionCard(),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: NavigationBar(
              height: bottomNavHeight,
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
                  selectedIcon: TotemIcon(
                    TotemIcons.homeFilled,
                    fillColor: false,
                  ),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: TotemIcon(TotemIcons.spaces),
                  selectedIcon: TotemIcon(
                    TotemIcons.spacesFilled,
                    fillColor: false,
                  ),
                  label: 'Sessions',
                ),
                NavigationDestination(
                  icon: TotemIcon(TotemIcons.blog),
                  selectedIcon: TotemIcon(
                    TotemIcons.blogFilled,
                    fillColor: false,
                  ),
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
        ],
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
  } else if (navigatorKey.currentState != null) {
    navigatorKey.currentState!.pushReplacementNamed(RouteNames.welcome);
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
    observers: [
      PosthogObserver(),
      SentryNavigatorObserver(),
    ],
    redirect: (context, state) async {
      logger.i('🛻 Router State Change: ${state.fullPath}');

      final isLoggedIn = authController.isAuthenticated;
      final isOnboardingCompleted = authController.isOnboardingCompleted;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnboardingRoute = state.matchedLocation == RouteNames.onboarding;
      final isWelcomeRoute = state.matchedLocation == RouteNames.welcome; // '/'

      // Unauthenticated flow
      if (!isLoggedIn) {
        final hasSeenWelcomeOnboarding =
            await authController.hasSeenWelcomeOnboarding;

        if (isWelcomeRoute) {
          // First-time users stay on welcome; returning users go to login
          return hasSeenWelcomeOnboarding ? RouteNames.login : null;
        }

        // Auth pages are allowed when logged out
        if (isAuthRoute) return null;

        // Any other route requires auth
        return RouteNames.login;
      }

      // Logged-in flow
      if (!isOnboardingCompleted) {
        // Force onboarding until completed
        return isOnboardingRoute ? null : RouteNames.onboarding;
      }

      // Logged-in and onboarded: keep them off auth/welcome routes
      if (isAuthRoute || isWelcomeRoute) {
        return RouteNames.home;
      }

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
                  child: const SentryDisplayWidget(child: HomeScreen()),
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
                  child: const SentryDisplayWidget(
                    child: SpacesDiscoveryScreen(),
                  ),
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
                builder: (context, state) =>
                    const SentryDisplayWidget(child: BlogListScreen()),
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
        path: RouteNames.space(':slug'),
        name: RouteNames.space(':slug'),
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return SentryDisplayWidget(child: SpaceDetailScreen(slug: slug));
        },
      ),

      GoRoute(
        path: RouteNames.spaceEvent(':spaceSlug', ':eventSlug'),
        name: RouteNames.spaceEvent(':spaceSlug', ':eventSlug'),
        builder: (context, state) {
          final spaceSlug = state.pathParameters['spaceSlug'] ?? '';
          final eventSlug = state.pathParameters['eventSlug'];
          return SentryDisplayWidget(
            child: SpaceDetailScreen(slug: spaceSlug, eventSlug: eventSlug),
          );
        },
      ),

      GoRoute(
        path: RouteNames.keeperProfile(':slug'),
        name: RouteNames.keeperProfile(':slug'),
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return SentryDisplayWidget(child: KeeperProfileScreen(slug: slug));
        },
      ),

      GoRoute(
        path: RouteNames.blogPost(':slug'),
        name: RouteNames.blogPost(':slug'),
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return SentryDisplayWidget(child: BlogScreen(slug: slug));
        },
      ),

      GoRoute(
        path: RouteNames.videoSessionPrejoin,
        name: RouteNames.videoSessionPrejoin,
        builder: (context, state) {
          return SentryDisplayWidget(
            child: PreJoinScreen(eventSlug: state.extra! as String),
          );
        },
      ),
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
  Future<void> dispose() async {
    await _subscription.cancel();
    super.dispose();
  }
}
