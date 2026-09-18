// Do not need to reach main directly

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/shared/logger.dart';
import 'package:totem_core/shared/router.dart';

final notificationsProvider = Provider<NotificationsService>((ref) {
  return NotificationsService.instance;
}, name: 'Notifications Provider');

final class NotificationType {
  static const String circleStarting = 'circle_starting';
  static const String circleAdvertisement = 'circle_advertisement';
  static const String missedEvent = 'missed_event';
  static const String directMessage = 'direct_message';
  static const String messageReceived = 'message_received';
}

const _backgroundKey = 'initial_payload';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  final payload = notificationResponse.payload;
  if (payload == null) return;

  try {
    await SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString(_backgroundKey, payload);
    });
  } catch (error, stackTrace) {
    ErrorHandler.logError(
      error,
      stackTrace: stackTrace,
      message: 'Failed to save background notification payload',
    );
  }
}

class NotificationsService {
  NotificationsService._internal();
  static final NotificationsService _instance =
      NotificationsService._internal();
  static NotificationsService get instance => _instance;

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final _handledMessageIds = <String>{};
  void Function(String conversationId)? onDirectMessage;
  String? visibleConversationId;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      logger.i('⏰ Initializing NotificationsService...');
      _initialized = true;

      // Set up Firebase
      {
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          _handleFirebaseMessage(initialMessage);
        }
        FirebaseMessaging.onMessageOpenedApp.listen(_handleFirebaseMessage);

        FirebaseMessaging.onMessage.listen((message) {
          logger
            ..i('⏰ Got a message whilst in the foreground!')
            ..i('⏰ Message data: ${message.data}');
          _handlePayload(message.data, navigate: false);

          final conversationId = message.data['conversation_id'] as String?;
          final notificationType =
              message.data['type'] ?? message.data['category'];
          final isVisibleDirectMessage =
              (notificationType == NotificationType.directMessage ||
                  notificationType == NotificationType.messageReceived) &&
              conversationId == visibleConversationId;
          if (message.notification != null && !isVisibleDirectMessage) {
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
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );
        await flutterLocalNotificationsPlugin.initialize(
          settings: initializationSettings,
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

      {
        final prefs = await SharedPreferences.getInstance();
        final payload = prefs.getString(_backgroundKey);
        if (payload != null) {
          _handlePayload(jsonDecode(payload) as Map);
          await prefs.remove(_backgroundKey);
        }
      }

      logger.i('⏰ NotificationsService initialized successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to initialize notifications service',
      );
      // Fail gracefully - mark as initialized anyway
      _initialized = true;
    }
  }

  void _handleFirebaseMessage(RemoteMessage message) {
    logger.i('⏰ Handling message: ${message.data}');
    _handlePayload(message.data);
  }

  void _handleNotificationTap(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload != null) {
      logger.d('⏰ Notification payload: $payload');
      final deserializedPayload = jsonDecode(payload) as Map;
      _handlePayload(deserializedPayload);
    }
  }

  void _handlePayload(Map<dynamic, dynamic> payload, {bool navigate = true}) {
    final type = (payload['type'] ?? payload['category']) as String?;
    if (type != null) {
      switch (type) {
        case NotificationType.directMessage:
        case NotificationType.messageReceived:
          if (!AppConfig.instance.messagesEnabled) return;
          final conversationId = payload['conversation_id'] as String?;
          final messageId = payload['message_id'] as String?;
          if (conversationId == null || conversationId.isEmpty) return;
          if (messageId == null || _handledMessageIds.add(messageId)) {
            onDirectMessage?.call(conversationId);
          }
          if (navigate) _handlePath(RouteNames.messageThread(conversationId));
          return;
        case NotificationType.circleStarting:
        case NotificationType.circleAdvertisement:
        case NotificationType.missedEvent:
          final spaceSlug = payload['space_slug'] as String?;
          final sessionSlug = payload['event_slug'] as String?;
          if (spaceSlug != null && sessionSlug != null) {
            _handlePath(RouteNames.spaceSession(spaceSlug, sessionSlug));
          }
          return;
        default:
          logger.w('⏰ Unknown notification type: $type. No action taken.');
          return;
      }
    }
  }

  void _handlePath(String? path) {
    logger.i('⏰ Handling path: $path');
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        logger.i('⏰ Handled path: $path');
        await TotemRouter.instance.navigatorKey.currentContext?.push(path);
      });
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'spaces',
        'Spaces',
        channelDescription: 'Spaces',
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Color(0xFFF4DC92),
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

    final payload = jsonEncode(data);

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.timestamp().millisecondsSinceEpoch % 2147483647,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<String?> get fcmToken {
    return FirebaseMessaging.instance.getToken(
      vapidKey: AppConfig.instance.vapidKey,
    );
  }

  Future<void> requestPermissions() {
    try {
      return FirebaseMessaging.instance.requestPermission(provisional: true);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request notification permissions',
      );
      return Future.value();
    }
  }
}
