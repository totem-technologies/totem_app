part of 'livekit_service.dart';

extension on LiveKitService {
  Future<void> setupBackgroundMode() async {
    try {
      await _requestPermissions();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'totem_session',
          channelName: 'Totem Session',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
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

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      unawaited(_updateNotification());
    });
  }

  Future<void> _updateNotification() async {
    try {
      final event = await this.event;
      final startTime = event.start;
      final duration = DateTime.now().difference(startTime);
      final formattedTime = DateFormat(
        'HH:mm:ss',
      ).format(DateTime(0).add(duration).toUtc());

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
      _timer?.cancel();
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // fine if fail
    }
  }

  Future<void> _requestPermissions() async {
    // Android 13+, it's needed to allow notification permission to display
    // foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // Android 12+, there are restrictions on starting a foreground service.
      //
      // To restart the service on device reboot or unexpected problem, you need
      // to allow below permission.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }
}
