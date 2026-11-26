// Do not need to reach main directly
// ignore_for_file: unreachable_from_main

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:totem_core/core/api/api_client/models/session_notification_payload.dart';

import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/shared/logger.dart';

final notificationsProvider = Provider<NotificationsService>((ref) {
  return NotificationsService.instance;
}, name: 'Notifications Provider');

const _backgroundKey = 'initial_payload';
const _backgroundIdentityKey = 'initial_payload_identity';
const _backgroundTimestampKey = 'initial_payload_timestamp';
const _maxBackgroundPayloadLength = 8192;
const _backgroundPayloadMaxAge = Duration(hours: 24);
const _maxHandledInteractionIds = 256;
const _maxPendingInteractions = 64;

typedef NotificationInteractionHandler =
    void Function(SessionNotificationPayload payload);

String? _transportMessageId(String serializedPayload) {
  try {
    final value = jsonDecode(serializedPayload);
    if (value is! Map) return null;
    final messageId = value['message_id'];
    return messageId is String && messageId.isNotEmpty ? messageId : null;
  } catch (_) {
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  final payload = notificationResponse.payload;

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.remove(_backgroundKey);
    await prefs.remove(_backgroundIdentityKey);
    await prefs.remove(_backgroundTimestampKey);
    if (payload == null || payload.length > _maxBackgroundPayloadLength) return;

    final messageId = _transportMessageId(payload);
    await prefs.setString(_backgroundKey, payload);
    await prefs.setString(
      _backgroundIdentityKey,
      messageId == null
          ? 'local:${notificationResponse.id}'
          : 'message:$messageId',
    );
    await prefs.setInt(
      _backgroundTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (error, stackTrace) {
    ErrorHandler.logError(
      error,
      stackTrace: stackTrace,
      message: 'Failed to save background notification payload',
    );
  }
}

typedef _NotificationErrorReporter =
    void Function(Object error, StackTrace stackTrace, String message);

Future<AuthorizationStatus> _readFirebaseNotificationPermission() async =>
    (await FirebaseMessaging.instance.getNotificationSettings())
        .authorizationStatus;

void _reportUnexpectedNotificationError(
  Object error,
  StackTrace stackTrace,
  String message,
) {
  ErrorHandler.report(
    error,
    stackTrace: stackTrace,
    message: message,
    incidentKey: 'notifications:$message:${error.runtimeType}',
    diagnostics: {'feature': 'notifications'},
  );
}

class NotificationsService with WidgetsBindingObserver {
  NotificationsService._internal()
    : _readNotificationPermission = _readFirebaseNotificationPermission,
      _reportUnexpectedError = _reportUnexpectedNotificationError;

  @visibleForTesting
  NotificationsService.forTesting({
    required Future<AuthorizationStatus> Function() permissionReader,
    required void Function(Object error, StackTrace stackTrace, String message)
    errorReporter,
  }) : _readNotificationPermission = permissionReader,
       _reportUnexpectedError = errorReporter,
       _firebaseInitialized = true;

  static final NotificationsService _instance =
      NotificationsService._internal();
  static NotificationsService get instance => _instance;

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _lifecycleObserverRegistered = false;
  bool _firebaseInitialized = false;
  bool _localNotificationsReady = false;
  bool _localInitializationAttempted = false;
  bool _notificationPermissionGranted = false;
  final Future<AuthorizationStatus> Function() _readNotificationPermission;
  final _NotificationErrorReporter _reportUnexpectedError;
  Future<void>? _localInitialization;
  Future<void>? _permissionRefresh;
  bool _permissionRefreshRequested = false;
  bool _initialLocalNotificationChecked = false;
  int _lastNotificationId = 0;
  Future<void>? _initialization;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  final _pendingInteractions = <SessionNotificationPayload>[];
  final _handledInteractionIds = <String>{};
  NotificationInteractionHandler? _interactionHandler;

  /// Attaches the router-facing callback and delivers interactions received so
  /// far, including cold-start notification taps.
  void attachInteractionHandler(NotificationInteractionHandler handler) {
    _interactionHandler = handler;
    while (_pendingInteractions.isNotEmpty &&
        identical(_interactionHandler, handler)) {
      _deliverInteraction(_pendingInteractions.removeAt(0), handler);
    }
  }

  void detachInteractionHandler(NotificationInteractionHandler handler) {
    if (identical(_interactionHandler, handler)) _interactionHandler = null;
  }

  Future<void> refreshPermissionStatus() => _refreshNotificationPermission();

  Future<void> initialize() {
    if (_initialized) return Future.value();
    if (!_lifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverRegistered = true;
    }
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    logger.i('⏰ Initializing NotificationsService...');
    if (!_firebaseInitialized) {
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false,
              badge: false,
              sound: false,
            );
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          _handleFirebaseMessage(initialMessage, isInteraction: true);
        }
        _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp
            .listen((message) {
              _handleFirebaseMessage(message, isInteraction: true);
            });
        _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen((
          message,
        ) {
          final payload = _decodePayload(message.data);
          if (message.notification != null) {
            unawaited(
              showNotification(
                title: message.notification?.title ?? '',
                body: message.notification?.body ?? '',
                payload: payload,
                messageId: message.messageId,
              ),
            );
          }
        });
        _firebaseInitialized = true;
      } catch (error, stackTrace) {
        _reportUnexpectedError(
          error,
          stackTrace,
          'Failed to initialize Firebase messaging',
        );
      }
    }

    if (_firebaseInitialized) await _refreshNotificationPermission();
    if (!_localInitializationAttempted) await _initializeLocalNotifications();

    if (_localNotificationsReady && !_initialLocalNotificationChecked) {
      await _handleInitialLocalNotification();
    }

    if (!await _restoreBackgroundPayload()) return;
    _initialized = _firebaseInitialized && _localInitializationAttempted;
    if (_initialized) {
      logger.i(
        '⏰ NotificationsService initialized '
        '(local notifications ready: $_localNotificationsReady)',
      );
    }
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
      _reportUnexpectedError(
        error,
        stackTrace,
        'Failed to handle initial local notification',
      );
    }
  }

  Future<bool> _restoreBackgroundPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final serializedPayload = prefs.getString(_backgroundKey);
      final timestamp = prefs.getInt(_backgroundTimestampKey);
      if (serializedPayload != null &&
          serializedPayload.length <= _maxBackgroundPayloadLength &&
          timestamp != null &&
          _isRecentBackgroundPayload(timestamp)) {
        final interaction = _decodeSerializedPayload(serializedPayload);
        if (interaction != null) {
          _handleNotificationInteraction(
            interaction,
            prefs.getString(_backgroundIdentityKey),
          );
        }
      }
      await prefs.remove(_backgroundKey);
      await prefs.remove(_backgroundIdentityKey);
      await prefs.remove(_backgroundTimestampKey);
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

  void _handleFirebaseMessage(
    RemoteMessage message, {
    bool isInteraction = false,
  }) {
    final payload = _decodePayload(message.data);
    if (payload == null || !isInteraction) return;
    _handleNotificationInteraction(
      payload,
      message.messageId == null ? null : 'message:${message.messageId}',
    );
  }

  void _handleNotificationTap(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload != null) {
      final interaction = _decodeSerializedPayload(payload);
      if (interaction != null) {
        final messageId = _transportMessageId(payload);
        _handleNotificationInteraction(
          interaction,
          messageId == null
              ? 'local:${notificationResponse.id}'
              : 'message:$messageId',
        );
      }
    }
  }

  SessionNotificationPayload? _decodeSerializedPayload(String value) {
    try {
      return _decodePayload(jsonDecode(value));
    } catch (error) {
      logger.w('⏰ Ignoring malformed notification JSON');
      return null;
    }
  }

  SessionNotificationPayload? _decodePayload(Object? value) {
    try {
      if (value is! Map) return null;
      final transport = Map<String, dynamic>.from(value);
      final rawPayload = transport['payload'] ?? transport;
      if (rawPayload is! Map) return null;
      final json = Map<String, dynamic>.from(rawPayload);
      if (!SessionNotificationPayload.canParse(json)) return null;
      final payload = SessionNotificationPayload.fromJson(json);
      if (payload.type.isUnknown ||
          !_isSafeSlug(payload.spaceSlug) ||
          !_isSafeSlug(payload.sessionSlug)) {
        return null;
      }
      return payload;
    } catch (error) {
      logger.w('⏰ Ignoring invalid notification payload');
      return null;
    }
  }

  bool _isSafeSlug(String slug) =>
      RegExp(r'^[a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*$').hasMatch(slug);

  bool _isRecentBackgroundPayload(int timestamp) {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age >= 0 && age <= _backgroundPayloadMaxAge.inMilliseconds;
  }

  void _handleNotificationInteraction(
    SessionNotificationPayload payload,
    String? identity,
  ) {
    if (identity != null && !_rememberInteraction(identity)) return;
    final handler = _interactionHandler;
    if (handler == null) {
      if (_pendingInteractions.length == _maxPendingInteractions) {
        _pendingInteractions.removeAt(0);
      }
      _pendingInteractions.add(payload);
    } else {
      _deliverInteraction(payload, handler);
    }
  }

  void _deliverInteraction(
    SessionNotificationPayload payload,
    NotificationInteractionHandler handler,
  ) {
    try {
      handler(payload);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Notification interaction handler failed',
      );
    }
  }

  bool _rememberInteraction(String identity) {
    if (_handledInteractionIds.contains(identity)) return false;
    if (_handledInteractionIds.length == _maxHandledInteractionIds) {
      _handledInteractionIds.remove(_handledInteractionIds.first);
    }
    _handledInteractionIds.add(identity);
    return true;
  }

  int _notificationIdForMessage(String messageId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in messageId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  int _newNotificationId() {
    final timestamp = DateTime.timestamp().millisecondsSinceEpoch % 2147483647;
    _lastNotificationId = timestamp > _lastNotificationId
        ? timestamp
        : (_lastNotificationId + 1) % 2147483647;
    return _lastNotificationId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _firebaseInitialized) {
      unawaited(_refreshNotificationPermission());
    }
  }

  Future<void> _initializeLocalNotifications() {
    return _localInitialization ??= _initializeLocalNotificationsOnce()
        .whenComplete(() => _localInitialization = null);
  }

  Future<void> _initializeLocalNotificationsOnce() async {
    _localInitializationAttempted = true;
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
      _localNotificationsReady = didInitialize == true;
    } catch (error, stackTrace) {
      _reportUnexpectedError(
        error,
        stackTrace,
        'Failed to initialize local notifications',
      );
    }
  }

  Future<void> _refreshNotificationPermission() {
    final ongoingRefresh = _permissionRefresh;
    if (ongoingRefresh != null) {
      _permissionRefreshRequested = true;
      return ongoingRefresh;
    }
    return _permissionRefresh = _refreshNotificationPermissionLoop();
  }

  Future<void> _refreshNotificationPermissionLoop() async {
    try {
      do {
        _permissionRefreshRequested = false;
        await _refreshNotificationPermissionOnce();
      } while (_permissionRefreshRequested);
    } finally {
      _permissionRefresh = null;
    }
  }

  Future<void> _refreshNotificationPermissionOnce() async {
    final previouslyGranted = _notificationPermissionGranted;
    try {
      final authorizationStatus = await _readNotificationPermission();
      _notificationPermissionGranted =
          authorizationStatus == AuthorizationStatus.authorized ||
          authorizationStatus == AuthorizationStatus.provisional;
      if (!previouslyGranted &&
          _notificationPermissionGranted &&
          _localInitializationAttempted &&
          !_localNotificationsReady) {
        final ongoingInitialization = _localInitialization;
        if (ongoingInitialization != null) await ongoingInitialization;
        if (!_localNotificationsReady) {
          _localInitializationAttempted = false;
          await _initializeLocalNotifications();
        }
        if (_localNotificationsReady && !_initialLocalNotificationChecked) {
          await _handleInitialLocalNotification();
        }
      }
    } catch (error, stackTrace) {
      _notificationPermissionGranted = false;
      _reportUnexpectedError(
        error,
        stackTrace,
        'Failed to check notification permission',
      );
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    SessionNotificationPayload? payload,
    String? messageId,
  }) async {
    if (!_localNotificationsReady || !_notificationPermissionGranted) return;
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
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.passive,
      ),
    );

    final serializedPayload = payload == null
        ? null
        : jsonEncode({'payload': payload.toJson(), 'message_id': ?messageId});

    try {
      await flutterLocalNotificationsPlugin.show(
        id: messageId == null
            ? _newNotificationId()
            : _notificationIdForMessage(messageId),
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: serializedPayload,
      );
    } catch (error, stackTrace) {
      _reportUnexpectedError(
        error,
        stackTrace,
        'Failed to display local notification',
      );
    }
  }
}
