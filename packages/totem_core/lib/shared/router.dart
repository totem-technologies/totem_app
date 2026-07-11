import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RouteNames {
  const RouteNames._();

  static const welcome = '/';

  // Auth routes
  static const login = '/auth/login';
  static const pinEntry = '/auth/pin';

  // Onboarding
  static const onboarding = '/onboarding';

  // Main app routes
  static const home = '/home';
  static const spaces = '/spaces';
  static const spaceDetail = '/spaces/session/';
  static String space(String slug) => '/spaces/$slug';
  static String spaceEvent(String eventSlug) => '/spaces/event/$eventSlug';
  static String spaceSession(String spaceSlug, String sessionSlug) =>
      '/spaces/$spaceSlug/session/$sessionSlug';

  static const profile = '/profile';
  static const profileDetail = '/profile/detail';
  static const subscribedSpaces = '/profile/subscribed-spaces';
  static const sessionHistory = '/profile/session-history';

  static String keeperProfile(String slug) => '/keeper/$slug';

  static const blog = '/blog';
  static const blogDetail = '/blog/detail';
  static String blogPost(String slug) => '/blog/$slug';

  static const messages = '/messages';
  static String messageThread(String conversationId) =>
      '/messages/$conversationId';

  static String session(String slug) => '/session/$slug';

  static const allRoutes = <String>[
    login,
    pinEntry,
    onboarding,
    spaces,
    spaceDetail,
    profile,
    profileDetail,
    subscribedSpaces,
    sessionHistory,
    blog,
    blogDetail,
    messages,
  ];
}

enum HomeRoutes {
  home(RouteNames.home),
  spaces(RouteNames.spaces),
  blog(RouteNames.blog),
  messages(RouteNames.messages),
  profile(RouteNames.profile);

  const HomeRoutes(this.path);

  final String path;

  static const HomeRoutes initialRoute = HomeRoutes.home;
}

abstract class TotemRouter {
  static late TotemRouter instance;

  GlobalKey<NavigatorState> get navigatorKey;

  Uri get baseUri;

  /// Pops the current route if possible, otherwise navigates to the home route.
  void popOrHome([BuildContext? context]);

  void toHome([HomeRoutes route = HomeRoutes.initialRoute]);

  Future<void> toKeeperProfile(BuildContext context, String userSlug);

  Future<void> toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]);

  GoRouter createRouter(WidgetRef ref);

  void setTabCloseConfirmationEnabled(bool enabled);
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
