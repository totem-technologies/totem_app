import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/main.dart' show TotemApp;
import 'package:totem_app/navigation/route_names.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // handle action
}

class NotificationsService {
  NotificationsService._internal();
  static final NotificationsService _instance =
      NotificationsService._internal();
  static NotificationsService get instance => _instance;

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('NotificationsService already initialized');
      return;
    }

    try {
      debugPrint('Initializing NotificationsService...');
      _initialized = true;

      // Set up Firebase
      {
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _handleFirebaseMessage(initialMessage);
        }
        FirebaseMessaging.onMessageOpenedApp.listen(_handleFirebaseMessage);
      }

      // Set up local notifications
      {
        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('app_icon'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );
        await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _handleNotificationTap,
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );

        final notificationAppLaunchDetails =
            await flutterLocalNotificationsPlugin
                .getNotificationAppLaunchDetails();
        if (notificationAppLaunchDetails?.notificationResponse != null) {
          _handleNotificationTap(
            notificationAppLaunchDetails!.notificationResponse!,
          );
        }
      }

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

  void _handleFirebaseMessage(RemoteMessage message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Handling message: ${message.data}');

      final path = message.data['path'] as String?;

      _handlePath(path);
    });
  }

  void _handleNotificationTap(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('Notification payload: $payload');
      final deserializedPayload = jsonDecode(payload) as Map;
      final path = deserializedPayload['path'] as String?;
      _handlePath(path);
    }
  }

  void _handlePath(String? path) {
    if (path != null && RouteNames.isValidRoute(path)) {
      TotemApp.navigatorKey.currentState?.pushNamed(path);
    }
  }

  Future<String?> get fcmToken {
    return FirebaseMessaging.instance.getToken(vapidKey: AppConfig.vapidKey);
  }

  Future<void> requestPermissions() {
    return FirebaseMessaging.instance.requestPermission(provisional: true);
  }
}
