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
    } catch (_) {
      // fine if fail
    }
  }

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
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (this.event != null) _updateNotification(this.event!);
    });
  }

  Future<void> _updateNotification(EventDetailSchema event) async {
    try {
      final startTime = event.start;
      final duration = DateTime.now().difference(startTime);
      final formattedTime =
          DateFormat(
            'HH:mm:ss',
          ).format(
            DateTime(
              0,
              1,
              1,
              duration.inHours,
              duration.inMinutes % 60,
              duration.inSeconds % 60,
            ),
          );

      await FlutterForegroundTask.updateService(
        notificationTitle: event.title,
        notificationText: formattedTime,
      );
    } catch (_) {
      // fine if fail
    }
  }

  Future<void> endBackgroundMode() async {
    try {
      _notificationTimer?.cancel();
      _notificationTimer = null;
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // fine if fail
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

    // TODO(bdlukaa): Make a beautiful UI asking for permission
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
