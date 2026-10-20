import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/permissions/notification_permissions.dart';

/// Notification permission through Firebase Messaging, which covers iOS and
/// Android 13+. The only call to `requestPermission` in the app.
class FirebaseNotificationPermissions implements NotificationPermissions {
  const new();

  @override
  Future<void> request() async {
    try {
      await FirebaseMessaging.instance.requestPermission(provisional: true);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request notification permissions',
      );
    }
  }
}
