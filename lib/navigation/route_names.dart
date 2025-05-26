class RouteNames {
  const RouteNames._();

  static const welcome = '/';

  // Auth routes
  static const login = '/auth/login';
  static const pinEntry = '/auth/pin';
  static const magicLink = '/auth/magic-link';

  // Onboarding
  static const onboarding = '/onboarding';

  // Main app routes
  static const spaces = '/spaces';
  static const spaceDetail = '/space';
  static String space(String id) => '/spaces/$id';

  static const profile = '/profile';
  static const profileDetail = '/profile/detail';
  static const subscribedSpaces = '/profile/subscribed-spaces';
  static const sessionHistory = '/profile/session-history';

  static const allRoutes = [
    login,
    pinEntry,
    magicLink,
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
