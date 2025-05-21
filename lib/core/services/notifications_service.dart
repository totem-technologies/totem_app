import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/main.dart' show TotemApp;
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/logger.dart';

final notificationsProvider = Provider<NotificationsService>((ref) {
  return NotificationsService.instance;
});

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // TODO(bdlukaa): handle action
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
      return;
    }

    try {
      logger.d('⏰ Initializing NotificationsService...');
      _initialized = true;

      // Set up Firebase
      {
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _handleFirebaseMessage(initialMessage);
        }
        FirebaseMessaging.onMessageOpenedApp.listen(_handleFirebaseMessage);

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          logger
            ..i('⏰ Got a message whilst in the foreground!')
            ..i('⏰ Message data: ${message.data}');

          if (message.notification != null) {
            logger.i(
              '⏰ Message also contained a notification: '
              '${message.notification}',
            );

            showNotification(
              title: message.notification?.title ?? '',
              body: message.notification?.body ?? '',
              data: message.data,
            );
          }
        });
      }

      // Set up local notifications
      {
        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
        if (notificationAppLaunchDetails?.notificationResponse != null &&
            (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false)) {
          _handleNotificationTap(
            notificationAppLaunchDetails!.notificationResponse!,
          );
        }
      }

      logger.d('⏰ NotificationsService initialized successfully');
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
    logger.d('⏰ Handling message: ${message.data}');

    final path = message.data['path'] as String?;

    _handlePath(path);
  }

  void _handleNotificationTap(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload != null) {
      logger.d('⏰ Notification payload: $payload');
      final deserializedPayload = jsonDecode(payload) as Map;
      final path = deserializedPayload['path'] as String?;
      _handlePath(path);
    }
  }

  void _handlePath(String? path) {
    if (path != null && RouteNames.isValidRoute(path)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TotemApp.navigatorKey.currentState?.pushNamed(path);
      });
    }
  }

  void showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'spaces',
        'Spaces',
        channelDescription: 'Spaces',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: DefaultStyleInformation(true, true),
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.passive,
      ),
    );

    final payload = jsonEncode({'path': data['path']});

    flutterLocalNotificationsPlugin.show(
      Random().nextInt(10000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<String?> get fcmToken {
    return FirebaseMessaging.instance.getToken(vapidKey: AppConfig.vapidKey);
  }

  Future<void> requestPermissions() {
    return FirebaseMessaging.instance.requestPermission(provisional: true);
  }
}
