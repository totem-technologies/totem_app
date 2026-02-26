part of 'session_service.dart';

extension BackgroundControl on Session {
  Future<void> setupBackgroundMode() async {
    try {
      await requestPermissions();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'totem_session',
          channelName: 'Totem Session',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      await _startBackgroundService();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error setting up background mode',
      );
    }
  }

  static const _notificationPeriod = Duration(minutes: 1);

  Future<void> _startBackgroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'Totem Session',
      notificationText: 'Connecting...',
      serviceTypes: [
        ForegroundServiceTypes.microphone,
        ForegroundServiceTypes.mediaPlayback,
      ],
    );

    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(_notificationPeriod, (timer) {
      if (this.event != null) _updateNotification(this.event!);
    });
  }

  Future<void> _updateNotification(SessionDetailSchema event) async {
    try {
      final endTime = event.start.add(Duration(minutes: event.duration));
      final minutesLeft = endTime.difference(DateTime.now()).inMinutes;

      await FlutterForegroundTask.updateService(
        notificationTitle: event.title,
        notificationText: minutesLeft.isNegative
            ? 'at ${event.space.title}'
            : '$minutesLeft minutes left',
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error updating background notification',
      );
    }
  }

  Future<void> endBackgroundMode() async {
    try {
      _notificationTimer?.cancel();
      _notificationTimer = null;
    } catch (_) {}

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error stopping background service',
      );
    }
  }

  static Future<bool> requestPermissions() async {
    // Android 13+, it's needed to allow notification permission to display
    // foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    var notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      notificationPermission =
          await FlutterForegroundTask.requestNotificationPermission();
    }

    if (notificationPermission != NotificationPermission.granted) {
      return false;
    }

    if (Platform.isAndroid) {
      // Android 12+, there are restrictions on starting a foreground service.
      //
      // To restart the service on device reboot or unexpected problem, you need
      // to allow below permission.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // https://developer.android.com/reference/android/provider/Settings#ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
        // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
        final granted =
            await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        return granted;
      }
    }
    return true;
  }
}
