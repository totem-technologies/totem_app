import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-wide configuration settings
class AppConfig {
  // Private constructor to prevent instantiation
  const AppConfig._();

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
  static String get mobileApiUrl {
    return dotenv.get('MOBILE_API_URL', fallback: 'https://www.totem.org/');
    // return dotenv.get('MOBILE_API_URL', fallback: 'https://www.totem.kbl.io/');
    // return dotenv.get('MOBILE_API_URL', fallback: 'http://localhost:8000/');
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

  static bool get enablePushNotifications {
    return dotenv.env['ENABLE_PUSH_NOTIFICATIONS']?.toLowerCase() == 'true';
  }

  /// Vapid Key used for push notifications on the web.
  static String? get vapidKey {
    return dotenv.env['VAPID_KEY'];
  }

  static bool get enableAnalytics {
    if (kDebugMode) return false;
    return dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() != 'false';
  }

  static String get sentryDsn {
    return dotenv.env['SENTRY_DSN'] ??
        'https://66cc97ae272344978f48840710f857a0@o1324443.ingest.us.sentry.io/6582849';
  }

  static String get posthogApiKey {
    return dotenv.env['POSTHOG_API_KEY'] ??
        'phc_OJCztWvtlN5scoDe58jLipnOTCBugeidvZlni3FIy9z';
  }

  static String get posthogHost {
    // or EU Host: 'https://eu.i.posthog.com'
    return dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
  }

  static Uri get privacyPolicyUrl {
    return Uri.parse(
      dotenv.env['PRIVACY_POLICY_URL'] ?? 'https://www.totem.org/privacy/',
    );
  }

  static Uri get termsOfServiceUrl {
    return Uri.parse(
      dotenv.env['TERMS_OF_SERVICE_URL'] ?? 'https://www.totem.org/tos/',
    );
  }
}
