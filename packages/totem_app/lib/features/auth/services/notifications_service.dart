// Do not need to reach main directly
// ignore_for_file: unreachable_from_main

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _firebaseInitialized = false;
  bool _localNotificationsReady = false;
  bool _initialLocalNotificationChecked = false;
  Future<void>? _initialization;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    logger.i('⏰ Initializing NotificationsService...');
    if (!_firebaseInitialized) {
      try {
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) _handleFirebaseMessage(initialMessage);
        _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp
            .listen(_handleFirebaseMessage);
        _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen((
          message,
        ) {
          if (message.notification != null) {
            unawaited(
              showNotification(
                title: message.notification?.title ?? '',
                body: message.notification?.body ?? '',
                data: message.data,
              ),
            );
          }
        });
        _firebaseInitialized = true;
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to initialize Firebase messaging',
        );
      }
    }

    if (!_localNotificationsReady) {
      try {
        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );
        final didInitialize = await flutterLocalNotificationsPlugin.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: _handleNotificationTap,
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        if (didInitialize != true) {
          throw StateError('Local notifications plugin did not initialize');
        }
        _localNotificationsReady = true;
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to initialize local notifications',
        );
        // Firebase remains available; leave this false for a later explicit
        // retry rather than claiming local notifications are operational.
      }
    }

    if (_localNotificationsReady && !_initialLocalNotificationChecked) {
      await _handleInitialLocalNotification();
    }

    if (!await _restoreBackgroundPayload()) return;
    if (!_firebaseInitialized || !_localNotificationsReady) return;

    _initialized = true;
    logger.i('⏰ NotificationsService initialized successfully');
  }

  Future<void> _handleInitialLocalNotification() async {
    try {
      final notificationAppLaunchDetails = await flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      _initialLocalNotificationChecked = true;
      if (notificationAppLaunchDetails?.notificationResponse != null &&
          (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false)) {
        _handleNotificationTap(
          notificationAppLaunchDetails!.notificationResponse!,
        );
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to handle initial local notification',
      );
    }
  }

  Future<bool> _restoreBackgroundPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = prefs.getString(_backgroundKey);
      if (payload != null) {
        _handlePayload(jsonDecode(payload) as Map);
        await prefs.remove(_backgroundKey);
      }
      return true;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to restore notification payload',
      );
      return false;
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

  void _handlePayload(Map<dynamic, dynamic> payload) {
    final type = payload['type'] as String?;
    if (type != null) {
      switch (type) {
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
    if (!_localNotificationsReady) return;
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'spaces',
        'Spaces',
        channelDescription: 'Spaces',
        icon: 'ic_notification',
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

    try {
      await flutterLocalNotificationsPlugin.show(
        id: DateTime.timestamp().millisecondsSinceEpoch % 2147483647,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (error, stackTrace) {
      ErrorHandler.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to display local notification',
        incidentKey: 'local-notification-display:${error.runtimeType}',
        diagnostics: {'feature': 'notifications'},
      );
    }
  }

  Future<String?> get fcmToken {
    return FirebaseMessaging.instance.getToken(
      vapidKey: AppConfig.instance.vapidKey,
    );
  }

  Future<void> requestPermissions() async {
    try {
      await FirebaseMessaging.instance.requestPermission(provisional: true);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request notification permissions',
      );
      return;
    }
  }
}
