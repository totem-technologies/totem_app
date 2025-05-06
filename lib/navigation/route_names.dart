class RouteNames {
  const RouteNames._();

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
}
