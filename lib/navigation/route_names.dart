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
  static String space(String slug) => '/spaces/event/$slug';

  static const profile = '/profile';
  static const profileDetail = '/profile/detail';
  static const subscribedSpaces = '/profile/subscribed-spaces';
  static const sessionHistory = '/profile/session-history';

  static const blog = '/blog';
  static const blogDetail = '/blog/detail';
  static String blogPost(String slug) => '/blog/$slug';

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
    blog,
    blogDetail,
  ];

  static bool isValidRoute(String? route) {
    return allRoutes.contains(route);
  }
}
