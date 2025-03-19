/// Constants for API endpoints used throughout the app
class ApiEndpoints {
  // Private constructor to prevent instantiation
  ApiEndpoints._();

  // Base URL for the API
  static String get baseUrl {
    // In a real implementation, this would come from environment configs
    return 'https://api.totem.org/v1';
  }

  // Auth endpoints
  static const String requestMagicLink = '/auth/magic-link';
  static const String verifyMagicLink = '/auth/verify-magic-link';
  static const String verifyPin = '/auth/verify-pin';
  static const String validateApiKey = '/auth/validate-key';
  static const String revokeApiKey = '/auth/revoke-key';

  // User endpoints
  static String userProfile(String userId) => '/users/$userId';
  static String uploadProfileImage = '/users/profile-image';

  // Spaces endpoints
  static const String spaces = '/spaces';
  static String spaceDetail(String spaceId) => '/spaces/$spaceId';
  static String spaceSubscribe(String spaceId) => '/spaces/$spaceId/subscribe';

  // Sessions endpoints
  static const String sessions = '/sessions';
  static String sessionDetail(String sessionId) => '/sessions/$sessionId';
  static String sessionToken(String sessionId) => '/sessions/$sessionId/token';

  // Notification endpoints
  static const String notificationSettings = '/notifications/settings';
}
