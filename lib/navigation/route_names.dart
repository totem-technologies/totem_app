class RouteNames {
  const RouteNames._();

  static const welcome = '/';

  // Auth routes
  static const login = '/auth/login';
  static const pinEntry = '/auth/pin';
  static const communityGuidelines = '/auth/community-guidelines';

  // Onboarding
  static const onboarding = '/onboarding';

  // Main app routes
  static const home = '/home';
  static const spaces = '/spaces';
  static const spaceDetail = '/spaces/session/';
  static String space(String slug) => '/spaces/$slug';
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

  static const videoSessionPrejoin = '/video-session/join';

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
    videoSessionPrejoin,
  ];
}
