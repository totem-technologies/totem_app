import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/widgets/offline_indicator.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/features/keeper/screens/keeper_profile_screen.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared/logger.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/pin_entry_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/blog/screens/blog_list_screen.dart';
import '../features/blog/screens/blog_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/home/widgets/join_ongoing_session_card.dart';
import '../features/messages/screens/messages_screen.dart';
import '../features/messages/screens/new_message_screen.dart';
import '../features/messages/screens/session_participants_screen.dart';
import '../features/messages/screens/thread_screen.dart';
import '../features/profile/screens/profile_details_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/spaces/screens/event_deep_link_screen.dart';
import '../features/spaces/screens/session_history.dart';
import '../features/spaces/screens/space_detail_screen.dart';
import '../features/spaces/screens/spaces_discovery_screen.dart';
import '../features/spaces/screens/subcribed_spaces.dart';

class BottomNavScaffold extends ConsumerWidget {
  const BottomNavScaffold({
    required this.child,
    required this.currentPath,
    super.key,
  });
  final Widget child;
  final String currentPath;

  static const double bottomNavHeight = 80;

  static List<HomeRoutes> get _visibleRoutes => HomeRoutes.values
      .where(
        (r) =>
            AppConfig.instance.environment != Environment.production ||
            r != HomeRoutes.messages,
      )
      .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final visibleRoutes = _visibleRoutes;
    final currentRoute = visibleRoutes.firstWhere(
      (route) => currentPath.startsWith(route.path),
      orElse: () => HomeRoutes.initialRoute,
    );

    final isNonHomeTabRoot =
        currentRoute != HomeRoutes.home && currentPath == currentRoute.path;

    return PopScope(
      canPop: !isNonHomeTabRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (isNonHomeTabRoot) {
          TotemRouter.instance.toHome(HomeRoutes.home);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: switch (theme.brightness) {
          Brightness.dark => SystemUiOverlayStyle.light,
          Brightness.light => SystemUiOverlayStyle.dark,
        },
        child: Scaffold(
          body: OfflineIndicatorPage(child: child),
          extendBody: true,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const JoinOngoingSessionCard(),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: NavigationBar(
                  height: bottomNavHeight,
                  onDestinationSelected: (index) {
                    final route = visibleRoutes[index];
                    if (currentRoute == route) return;
                    if (route == HomeRoutes.spaces) {
                      ref
                        ..invalidate(mySessionsFilterProvider)
                        ..invalidate(selectedCategoryProvider);
                    }
                    logger.i('🛻 Navigating to: ${route.path}');
                    context.go(route.path);
                  },
                  selectedIndex: visibleRoutes.indexOf(currentRoute),
                  destinations: [
                    const NavigationDestination(
                      icon: TotemIcon(TotemIcons.home),
                      selectedIcon: TotemIcon(
                        TotemIcons.homeFilled,
                        fillColor: false,
                      ),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: TotemIcon(TotemIcons.spaces),
                      selectedIcon: TotemIcon(
                        TotemIcons.spacesFilled,
                        fillColor: false,
                      ),
                      label: 'Sessions',
                    ),
                    const NavigationDestination(
                      icon: TotemIcon(TotemIcons.blog),
                      selectedIcon: TotemIcon(
                        TotemIcons.blogFilled,
                        fillColor: false,
                      ),
                      label: 'Blog',
                    ),
                    if (AppConfig.instance.environment !=
                        Environment.production)
                      const NavigationDestination(
                        icon: TotemIcon(TotemIcons.messages),
                        selectedIcon: TotemIcon(
                          TotemIcons.messagesFilled,
                          fillColor: false,
                        ),
                        label: 'Messages',
                      ),
                    const NavigationDestination(
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
        ),
      ),
    );
  }
}

class AppTotemRouter extends TotemRouter {
  final _navigatorKey = GlobalKey<NavigatorState>();

  final shellNavigatorKey = GlobalKey<StatefulNavigationShellState>();

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
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

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) {
    if (shellNavigatorKey.currentState != null) {
      shellNavigatorKey.currentState?.goBranch(
        BottomNavScaffold._visibleRoutes.indexOf(route),
      );
    } else if (navigatorKey.currentContext != null) {
      navigatorKey.currentContext!.pushReplacement(RouteNames.welcome);
    }
  }

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {
    await context.push(RouteNames.keeperProfile(userSlug));
  }

  @override
  Future toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]) async {
    String route;
    if (sessionSlug != null) {
      route = RouteNames.spaceSession(spaceSlug, sessionSlug);
    } else {
      route = RouteNames.space(spaceSlug);
    }

    if (replacement) {
      return context.pushReplacement(route);
    } else {
      return context.push(route);
    }
  }

  @override
  GoRouter createRouter(WidgetRef ref) {
    final authController = ref.read(mobileAuthControllerProvider);

    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: GoRouterRefreshStream(authController.authStateChanges),
      observers: [PosthogObserver(), SentryNavigatorObserver()],
      redirect: (context, state) async {
        logger.i('🛻 Router State Change: ${state.fullPath}');

        final isLoggedIn = authController.isAuthenticated;
        final isOnboardingCompleted = authController.isOnboardingCompleted;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        final isOnboardingRoute =
            state.matchedLocation == RouteNames.onboarding;
        final isWelcomeRoute =
            state.matchedLocation == RouteNames.welcome; // '/'

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
          builder: (context, state) {
            final nextRoute = state.uri.queryParameters['next'];
            return LoginScreen(nextRoute: nextRoute);
          },
        ),
        GoRoute(
          path: RouteNames.pinEntry,
          name: RouteNames.pinEntry,
          builder: (context, state) {
            final String email =
                (state.uri.queryParameters['email']) ??
                ((state.extra as Map?)?['email'] as String?) ??
                '';
            final nextRoute =
                state.uri.queryParameters['next'] ??
                ((state.extra as Map?)?['nextRoute'] as String?);
            return PinEntryScreen(email: email, nextRoute: nextRoute);
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
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
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
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
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
            if (AppConfig.instance.environment != Environment.production)
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: RouteNames.messages,
                    name: RouteNames.messages,
                    pageBuilder: (context, state) => CustomTransitionPage(
                      key: state.pageKey,
                      child: const SentryDisplayWidget(child: MessagesScreen()),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 200),
                    ),
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
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
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
                      builder: (context, state) =>
                          const SubscribedSpacesScreen(),
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
          path: RouteNames.newMessage,
          builder: (context, state) => const NewMessageScreen(),
        ),

        GoRoute(
          path: '/messages/session/:sessionSlug/participants',
          builder: (context, state) {
            final session = state.extra as SessionDetailSchema;
            return SessionParticipantsScreen(session: session);
          },
        ),

        GoRoute(
          path: '/messages/:conversationId',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId'] ?? '';
            final conversation = state.extra as Conversation;
            return ThreadScreen(
              conversationId: conversationId,
              conversation: conversation,
            );
          },
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
          path: RouteNames.spaceEvent(':eventSlug'),
          name: RouteNames.spaceEvent(':eventSlug'),
          builder: (context, state) {
            final eventSlug = state.pathParameters['eventSlug'] ?? '';
            return SentryDisplayWidget(
              child: EventDeepLinkScreen(eventSlug: eventSlug),
            );
          },
        ),

        GoRoute(
          path: RouteNames.spaceSession(':spaceSlug', ':eventSlug'),
          name: RouteNames.spaceSession(':spaceSlug', ':eventSlug'),
          builder: (context, state) {
            final spaceSlug = state.pathParameters['spaceSlug'] ?? '';
            final eventSlug = state.pathParameters['eventSlug'];
            return SentryDisplayWidget(
              child: SpaceDetailScreen(slug: spaceSlug, sessionSlug: eventSlug),
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
          path: RouteNames.session(':slug'),
          name: RouteNames.session(':slug'),
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return SentryDisplayWidget(child: PreJoinScreen(sessionSlug: slug));
          },
        ),
      ],
      errorBuilder: (context, state) => const ErrorScreen(),
    );
  }
}
