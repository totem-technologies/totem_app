import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static void check() {
    if (liveKitUrl == null || liveKitUrl!.isEmpty) {
      throw StateError('LIVEKIT_URL must be set in the environment variables');
    }

    if (kIsWeb && !isDevelopment && webApiUrl.isEmpty) {
      throw StateError(
        'WEB_API_URL must be set for non-development web builds',
      );
    }
  }

  /// Get the current environment (development, staging, production)
  static String get environment {
    return dotenv.env['ENVIRONMENT'] ?? 'production';
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
    return dotenv.get(
      'MOBILE_API_URL',
      // fallback: 'https://www.totem.org/',
      fallback: isStaging || isDevelopment
          ? 'https://totem.kbl.io/'
          : 'https://www.totem.org/',
    );
    // return dotenv.get('MOBILE_API_URL', fallback: 'http://localhost:8000/');
  }

  /// Web API configuration.
  ///
  /// Defaults to the current origin so cookie-based auth can work with a
  /// same-origin backend or reverse proxy.
  static String get webApiUrl {
    return dotenv.env['WEB_API_URL'] ?? '';
  }

  /// Returns the appropriate API base URL based on the platform.
  static String get apiBaseUrl {
    return kIsWeb ? webApiUrl : mobileApiUrl;
  }

  static String get apiHost {
    if (kIsWeb && webApiUrl.isEmpty) {
      return Uri.base.host.toLowerCase();
    }

    return Uri.parse(apiBaseUrl).host.toLowerCase();
  }

  /// LiveKit configuration
  static String? get liveKitUrl {
    return dotenv.env['LIVEKIT_URL'];
  }

  /// Maximum PIN attempts before reset
  static int get maxPinAttempts {
    return int.tryParse(dotenv.env['MAX_PIN_ATTEMPTS'] ?? '5') ?? 5;
  }

  /// Vapid Key used for push notifications on the web.
  static String? get vapidKey {
    return dotenv.env['VAPID_KEY'];
  }

  static bool get enableAnalytics {
    if (kDebugMode) return false;
    return dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() != 'false';
  }

  static String? get sentryDsn {
    return dotenv.env['SENTRY_DSN'];
  }

  static String? get posthogApiKey {
    return dotenv.env['POSTHOG_API_KEY'];
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

  static Uri get communityGuidelinesUrl {
    return Uri.parse(
      dotenv.env['COMMUNITY_GUIDELINES_URL'] ??
          'https://www.totem.org/guidelines/',
    );
  }
}
