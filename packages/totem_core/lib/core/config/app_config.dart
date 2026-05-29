import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thrown by [AppConfig.build] / [AppConfig.parse] when an environment
/// variable is missing or invalid.
///
/// Fatal and non-recoverable: the build is broken, not the runtime. Entry
/// points should let it crash the process (e.g. `exit(1)`) so CI smoke
/// tests can detect it.
class ConfigError extends Error {
  ConfigError(this.message);

  final String message;

  @override
  String toString() => 'ConfigError: $message';
}

/// Runtime environment the app is built for.
enum Environment {
  development,
  staging,
  production;

  static Environment parse(String? value) {
    for (final env in Environment.values) {
      if (env.name == value) return env;
    }
    throw ConfigError(
      'ENVIRONMENT must be one of '
      '${Environment.values.map((e) => e.name).join(', ')} '
      '(got: ${value == null ? 'unset' : "'$value'"})',
    );
  }
}

/// Immutable, strongly-typed app configuration.
///
/// Built once at startup via [AppConfig.build]; access via
/// [AppConfig.instance]. Tests can construct an instance directly (the
/// public constructor) or via [AppConfig.parse] with a synthetic env
/// string.
@immutable
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiUrl,
    required this.liveKitUrl,
    required this.maxPinAttempts,
    required this.vapidKey,
    required this.analyticsEnabled,
    required this.sentryDsn,
    required this.posthogApiKey,
    required this.posthogHost,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    required this.communityGuidelinesUrl,
  });

  /// Parses an `.env`-formatted string and builds a validated config.
  /// Uses a local [DotEnv] instance — does not touch the global singleton.
  factory AppConfig.parse(String envString) {
    final env = DotEnv()..loadFromString(envString: envString);
    return AppConfig._fromMap(env.env);
  }

  factory AppConfig._fromMap(Map<String, String> env) {
    final environment = Environment.parse(env['ENVIRONMENT']);

    final apiUrl = env['API_URL'];
    if (apiUrl == null || apiUrl.isEmpty) {
      throw ConfigError('API_URL must be set');
    }

    final liveKitUrl = env['LIVEKIT_URL'];
    if (liveKitUrl == null || liveKitUrl.isEmpty) {
      throw ConfigError('LIVEKIT_URL must be set');
    }

    return AppConfig(
      environment: environment,
      apiUrl: apiUrl,
      liveKitUrl: liveKitUrl,
      maxPinAttempts: int.tryParse(env['MAX_PIN_ATTEMPTS'] ?? '') ?? 5,
      vapidKey: env['VAPID_KEY'],
      analyticsEnabled:
          !kDebugMode && env['ENABLE_ANALYTICS']?.toLowerCase() != 'false',
      sentryDsn: env['SENTRY_DSN'],
      posthogApiKey: env['POSTHOG_API_KEY'],
      posthogHost: env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com',
      privacyPolicyUrl: Uri.parse(
        env['PRIVACY_POLICY_URL'] ?? 'https://www.totem.org/privacy/',
      ),
      termsOfServiceUrl: Uri.parse(
        env['TERMS_OF_SERVICE_URL'] ?? 'https://www.totem.org/tos/',
      ),
      communityGuidelinesUrl: Uri.parse(
        env['COMMUNITY_GUIDELINES_URL'] ?? 'https://www.totem.org/guidelines/',
      ),
    );
  }

  final Environment environment;
  final String apiUrl;
  final String liveKitUrl;
  final int maxPinAttempts;
  final String? vapidKey;
  final bool analyticsEnabled;
  final String? sentryDsn;
  final String? posthogApiKey;
  final String posthogHost;
  final Uri privacyPolicyUrl;
  final Uri termsOfServiceUrl;
  final Uri communityGuidelinesUrl;

  bool get isDevelopment =>
      environment == Environment.development || kDebugMode;

  String get apiHost => Uri.parse(apiUrl).host.toLowerCase();

  static AppConfig? _instance;

  /// The active app config. Must be assigned (via [build] or directly in
  /// tests) before access.
  static AppConfig get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'AppConfig.instance accessed before initialization. Call '
        'AppConfig.build() at startup or assign a test instance.',
      );
    }
    return i;
  }

  static set instance(AppConfig config) => _instance = config;

  /// Loads `.env` from the asset bundle and builds a validated config.
  /// Caller must ensure a `WidgetsBinding` is initialized first.
  static Future<AppConfig> build() async {
    final env = DotEnv();
    await env.load();
    return AppConfig._fromMap(env.env);
  }
}
