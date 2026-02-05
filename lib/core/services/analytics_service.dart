import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/shared/logger.dart';

final analyticsProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
}, name: 'Analytics Service Provider');

/// Service for tracking app analytics and user behavior.
///
/// This service provides a centralized way to track events, screen views,
/// user properties, and other analytics data across the app.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  var _isInitialized = false;
  final posthog = Posthog();

  /// Initialize the analytics service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logger.i('📊 Initializing analytics service');

      final config = PostHogConfig(AppConfig.posthogApiKey)
        ..debug = kDebugMode
        ..captureApplicationLifecycleEvents = true
        ..host = AppConfig.posthogHost
        ..sessionReplay = true;
      await posthog.setup(config);

      _isInitialized = true;

      logger.i('📊 Analytics initialized ');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to initialize analytics',
      );
      // Fail gracefully - don't let analytics crash the app
      _isInitialized = false;
    }
  }

  void logEvent(String eventName, {Map<String, Object>? parameters}) {
    if (!_shouldLog()) return;

    logger.i(
      '📊 Event: $eventName '
      '${parameters != null ? '| Params: $parameters' : ''}',
    );

    posthog.capture(eventName: eventName, properties: parameters ?? {});
  }

  Future<void> setUserId(UserSchema user) async {
    if (!_shouldLog()) return;
    logger.i('📊 Setting user ID: ${user.email}');

    await posthog.identify(
      userId: user.email,
      userProperties: {
        'email': user.email,
        if (user.name != null && user.name!.isNotEmpty) 'name': user.name!,
      },
    );

    await Sentry.configureScope((scope) async {
      await scope.setUser(
        SentryUser(
          id: user.slug,
          name: user.name,
          username: user.slug,
          data: {
            'is_staff': user.isStaff,
          },
        ),
      );

      await scope.setTag('user_type', user.isStaff ? 'staff' : 'user');
      await scope.addBreadcrumb(
        Breadcrumb(
          message: 'User identified: ${user.email}',
          level: SentryLevel.info,
          category: 'user',
          data: {
            'user_id': user.slug,
            'is_staff': user.isStaff.toString(),
          },
        ),
      );
    });
  }

  Future<void> logLogout() async {
    if (!_shouldLog()) return;
    logEvent('user_logged_out');
    await posthog.reset();
    await Sentry.configureScope((scope) => scope.setUser(null));
  }

  void logLogin({String? method}) {
    if (!_shouldLog()) return;

    logEvent(
      'user_logged_in',
      parameters: method != null ? {'method': method} : null,
    );
  }

  void logSpaceViewed(String spaceId) {
    if (!_shouldLog()) return;

    logEvent('space_viewed', parameters: {'space_id': spaceId});
  }

  bool _shouldLog() {
    if (!_isInitialized || kDebugMode) {
      return false;
    }

    return true;
  }
}
