class RouteNames {
  const RouteNames._();

  static const welcome = '/';

  // Auth routes
  static const login = '/auth/login';
  static const pinEntry = '/auth/pin';

  // Onboarding
  static const onboarding = '/onboarding';

  // Main app routes
  static const spaces = '/spaces';
  static const spaceDetail = '/spaces/event/';
  static String space(String id) => '/spaces/event/$id';

  static const profile = '/profile';
  static const profileDetail = '/profile/detail';
  static const subscribedSpaces = '/profile/subscribed-spaces';
  static const sessionHistory = '/profile/session-history';

  static const allRoutes = [
    login,
    pinEntry,
    onboarding,
    spaces,
    spaceDetail,
    profile,
    profileDetail,
    subscribedSpaces,
    sessionHistory,
  ];

  static bool isValidRoute(String? route) {
    return allRoutes.contains(route);
  }
}
