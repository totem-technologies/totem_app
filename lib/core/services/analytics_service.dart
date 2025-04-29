import 'package:flutter/foundation.dart';

/// Service for tracking app analytics and user behavior.
///
/// This service provides a centralized way to track events, screen views,
/// user properties, and other analytics data across the app.
class AnalyticsService {
  // Private constructor for singleton
  AnalyticsService._();
  // Singleton instance
  static final AnalyticsService instance = AnalyticsService._();

  // Flag to check if analytics is initialized
  bool _isInitialized = false;

  // Flag to enable/disable analytics (for privacy or development)
  bool _isEnabled = true;

  /// Initialize the analytics service.
  ///
  /// This would typically connect to your analytics provider
  /// (Firebase Analytics, Amplitude, Mixpanel, etc.)
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Analytics already initialized');
      return;
    }

    try {
      // For development, just log that we would initialize
      debugPrint('📊 Initializing analytics service');

      // In a real implementation, you would do something like:
      // await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      //   !kDebugMode,
      // );
      // or
      // await AmplitudeFlutter().init(apiKey);

      _isInitialized = true;
      _isEnabled = !kDebugMode; // Typically disable analytics in debug mode

      debugPrint(
        '📊 Analytics initialized '
        '(collection ${_isEnabled ? 'enabled' : 'disabled'})',
      );
    } catch (e) {
      debugPrint('📊 Failed to initialize analytics: $e');
      // Fail gracefully - don't let analytics crash the app
      _isInitialized = false;
      _isEnabled = false;
    }
  }

  /// Log a screen view event
  void logScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    if (!_shouldLog()) return;

    debugPrint(
      '📊 Screen View: $screenName '
      '${parameters != null ? '| Params: $parameters' : ''}',
    );
  }

  /// Log a custom event
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (!_shouldLog()) return;

    debugPrint(
      '📊 Event: $eventName '
      '${parameters != null ? '| Params: $parameters' : ''}',
    );
  }

  /// Set user properties
  void setUserProperties({required Map<String, dynamic> properties}) {
    if (!_shouldLog()) return;

    debugPrint('📊 Setting user properties: $properties');

    // Example:
    // For each property in the map:
    // FirebaseAnalytics.instance.setUserProperty(name: key, value: value);
  }

  /// Set user ID for analytics
  void setUserId(String? userId) {
    if (!_shouldLog()) return;

    debugPrint('📊 Setting user ID: $userId');

    // Example:
    // FirebaseAnalytics.instance.setUserId(id: userId);
  }

  /// Log authentication events
  void logLogin({String? method}) {
    if (!_shouldLog()) return;

    debugPrint('📊 Login event${method != null ? ' via $method' : ''}');

    // Example:
    // FirebaseAnalytics.instance.logLogin(method: method);
  }

  /// Log error events for monitoring
  void logError(String error, {StackTrace? stackTrace, String? reason}) {
    if (!_shouldLog()) return;

    debugPrint('📊 Error event: $error | Reason: $reason');

    // FirebaseCrashlytics.instance.recordError(
    //  error, stackTrace, reason: reason
    // );
  }

  /// Enable or disable analytics collection
  void setAnalyticsCollectionEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('📊 Analytics collection ${enabled ? 'enabled' : 'disabled'}');

    // Example:
    // FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  }

  /// Helper method to determine if we should log events
  bool _shouldLog() {
    if (!_isInitialized) {
      debugPrint('📊 Analytics not initialized, skipping logging');
      return false;
    }

    if (!_isEnabled) {
      return false;
    }

    return true;
  }
}
