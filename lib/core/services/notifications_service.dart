import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/main.dart' show TotemApp;
import 'package:totem_app/navigation/route_names.dart';

class NotificationsService {
  NotificationsService._internal();
  static final NotificationsService _instance =
      NotificationsService._internal();
  static NotificationsService get instance => _instance;

  bool _initialized = false;
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('NotificationsService already initialized');
      return;
    }

    try {
      debugPrint('Initializing NotificationsService...');
      _initialized = true;

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();

      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      debugPrint('NotificationsService initialized successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        reason: 'Failed to initialize notifications service',
      );
      // Fail gracefully - mark as initialized anyway
      _initialized = true;
      rethrow;
    }
  }

  void _handleMessage(RemoteMessage message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Handling message: ${message.data}');

      final path = message.data['path'] as String?;

      if (RouteNames.isValidRoute(path)) {
        TotemApp.navigatorKey.currentState?.pushNamed(path!);
      }
    });
  }

  Future<String?> get fcmToken {
    return FirebaseMessaging.instance.getToken(vapidKey: AppConfig.vapidKey);
  }

  Future<void> requestPermissions() {
    return FirebaseMessaging.instance.requestPermission(provisional: true);
  }
}
