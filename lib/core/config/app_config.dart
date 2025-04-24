import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-wide configuration settings
class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  /// Get the current environment (development, staging, production)
  static String get environment {
    return dotenv.env['ENVIRONMENT'] ?? 'development';
  }

  /// Check if the app is running in development mode
  static bool get isDevelopment {
    return environment == 'development' || kDebugMode;
  }

  /// Check if the app is running in staging mode
  static bool get isStaging {
    return environment == 'staging';
  }

  /// Check if the app is running in production mode
  static bool get isProduction {
    return environment == 'production';
  }

  /// API configuration
  static String get apiUrl {
    return dotenv.get('API_URL', fallback: 'https://www.totem.org/');
  }

  /// Auth configuration
  static Duration get magicLinkExpiration {
    // Default 30 minutes
    final minutes =
        int.tryParse(dotenv.env['MAGIC_LINK_EXPIRATION_MINUTES'] ?? '30') ?? 30;
    return Duration(minutes: minutes);
  }

  /// LiveKit configuration
  static String get liveKitUrl {
    return dotenv.env['LIVEKIT_URL'] ?? 'wss://livekit.totem.org';
  }

  /// App version information
  static String get appVersion {
    return dotenv.env['APP_VERSION'] ?? '1.0.0';
  }

  /// App build number
  static String get buildNumber {
    return dotenv.env['BUILD_NUMBER'] ?? '1';
  }

  /// Maximum PIN attempts before reset
  static int get maxPinAttempts {
    return int.tryParse(dotenv.env['MAX_PIN_ATTEMPTS'] ?? '5') ?? 5;
  }

  /// Feature flags
  static bool get enablePushNotifications {
    return dotenv.env['ENABLE_PUSH_NOTIFICATIONS']?.toLowerCase() == 'true';
  }

  /// Analytics configuration
  static bool get enableAnalytics {
    if (kDebugMode) return false; // Disable in debug mode
    return dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() !=
        'false'; // Enabled by default in release
  }
}
