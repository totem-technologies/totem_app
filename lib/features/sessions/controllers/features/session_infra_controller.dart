import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/screen_protection_service.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'session_infra_controller.g.dart';

@riverpod
class SessionInfraController extends _$SessionInfraController {
  @override
  void build(SessionOptions options) {
    ref.onDispose(dispose);
  }

  Timer? _notificationTimer;
  bool _wakelockEnabled = false;
  bool _backgroundModeEnabled = false;
  bool _screenProtectionEnabled = false;

  static const _notificationPeriod = Duration(minutes: 1);

  Future<void> activate({SessionDetailSchema? event}) async {
    await _enableWakelock();
    await _setupBackgroundMode(event);
    _applyScreenCapturePolicy();
  }

  Future<void> deactivate() async {
    await _endBackgroundMode();
    await _disableWakelock();
    _disableScreenProtection();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error enabling wakelock',
      );
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error disabling wakelock',
      );
    }
  }

  Future<void> _setupBackgroundMode(SessionDetailSchema? event) async {
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
      await _startBackgroundService(event);
      _backgroundModeEnabled = true;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error setting up background mode',
      );
    }
  }

  Future<void> _startBackgroundService(SessionDetailSchema? event) async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Totem Session',
        notificationText: 'Connecting...',
        serviceTypes: [
          ForegroundServiceTypes.microphone,
          ForegroundServiceTypes.mediaPlayback,
        ],
      );
    }

    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(_notificationPeriod, (_) {
      if (event != null) {
        _updateNotification(event);
      }
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

  Future<void> _endBackgroundMode() async {
    try {
      _notificationTimer?.cancel();
      _notificationTimer = null;
    } catch (_) {}

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      _backgroundModeEnabled = false;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error stopping background service',
      );
    }
  }

  static Future<bool> requestPermissions() async {
    var notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      notificationPermission =
          await FlutterForegroundTask.requestNotificationPermission();
    }

    if (notificationPermission != NotificationPermission.granted) {
      return false;
    }

    if (Platform.isAndroid &&
        !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      return FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return true;
  }

  void _applyScreenCapturePolicy() {
    try {
      final email = ref.read(authControllerProvider).user?.email;
      final shouldProtect =
          !ScreenProtectionService.shouldAllowScreenCaptureForEmail(email);
      ref
          .read(screenProtectionProvider)
          .setCaptureProtectionEnabled(shouldProtect);
      _screenProtectionEnabled = shouldProtect;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error applying screen capture policy',
      );
    }
  }

  void _disableScreenProtection() {
    try {
      ref.read(screenProtectionProvider).setCaptureProtectionEnabled(false);
      _screenProtectionEnabled = false;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error disabling screen capture policy',
      );
    }
  }

  void dispose() {
    _notificationTimer?.cancel();
    if (_backgroundModeEnabled ||
        _wakelockEnabled ||
        _screenProtectionEnabled) {
      unawaited(deactivate());
    }
  }
}
