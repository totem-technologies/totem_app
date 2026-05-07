import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';

part 'session_infra_controller.g.dart';

@riverpod
class SessionInfraController extends _$SessionInfraController {
  @override
  void build() {
    ref.onDispose(dispose);
  }

  static bool get canUseForegroundTask {
    return !kIsWeb && !kIsWasm && (Platform.isAndroid || Platform.isIOS);
  }

  Timer? _notificationTimer;
  bool _backgroundModeEnabled = false;

  static const _notificationPeriod = Duration(minutes: 1);

  Future<void> activate({SessionDetailSchema? event}) async {
    _setupBackgroundMode(event);
  }

  Future<void> deactivate() async {
    _endBackgroundMode();
  }

  Future<void> _setupBackgroundMode(SessionDetailSchema? event) async {
    try {
      await requestPermissions();

      if (canUseForegroundTask) {
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
      }
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
    if (!canUseForegroundTask) return;
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

    if (canUseForegroundTask) {
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
    _backgroundModeEnabled = false;
  }

  static Future<bool> requestPermissions() async {
    if (!canUseForegroundTask) {
      // Infra permissions aren't relevant on web, so we can skip requesting them.
      return true;
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
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
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error requesting notification permission',
      );
    }

    return false;
  }

  void dispose() {
    _notificationTimer?.cancel();
    if (_backgroundModeEnabled) {
      deactivate();
    }
  }
}
