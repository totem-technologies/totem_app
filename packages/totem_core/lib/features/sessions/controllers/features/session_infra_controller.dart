import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';

part 'session_infra_controller.g.dart';

class SessionInfraPlatform {
  const SessionInfraPlatform();

  bool get canUseForegroundTask =>
      !kIsWeb && !kIsWasm && (Platform.isAndroid || Platform.isIOS);

  Future<bool> get isRunningService => FlutterForegroundTask.isRunningService;

  void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'totem_session',
        channelName: 'Totem session',
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
  }

  Future<void> startService() => FlutterForegroundTask.startService(
    notificationTitle: 'Totem session',
    notificationText: 'Connecting...',
    serviceTypes: [
      ForegroundServiceTypes.microphone,
      ForegroundServiceTypes.mediaPlayback,
    ],
  );

  Future<void> stopService() => FlutterForegroundTask.stopService();

  Future<void> updateNotification({
    required String title,
    required String text,
  }) => FlutterForegroundTask.updateService(
    notificationTitle: title,
    notificationText: text,
  );
}

@riverpod
class SessionInfraController extends _$SessionInfraController {
  SessionInfraController({SessionInfraPlatform? platform})
    : _platform = platform ?? const SessionInfraPlatform();

  final SessionInfraPlatform _platform;

  @override
  void build() {
    ref.onDispose(dispose);
  }

  Timer? _notificationTimer;
  Future<void> _operation = Future.value();
  bool _disposed = false;

  static const _notificationPeriod = Duration(minutes: 1);

  Future<void> activate({SessionDetailSchema? event}) {
    return _enqueue(() => _setupBackgroundMode(event));
  }

  Future<void> deactivate() {
    return _enqueue(_endBackgroundMode);
  }

  Future<void> _enqueue(AsyncCallback operation) =>
      _operation = _operation.catchError((_) {}).then((_) => operation());

  /// Starts the foreground service that keeps the microphone alive through
  /// brief app switches.
  ///
  /// Asks for nothing: the service runs without notification permission (its
  /// notification is just hidden), and its only requirement is the
  /// microphone, which joining already needs. See N2 and N5 in
  /// specs/permissions.md.
  Future<void> _setupBackgroundMode(SessionDetailSchema? event) async {
    if (_disposed || !_platform.canUseForegroundTask) return;
    try {
      _platform.initialize();
      await _startBackgroundService(event);
      if (_disposed) await _endBackgroundMode();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error setting up background mode',
      );
    }
  }

  Future<void> _startBackgroundService(SessionDetailSchema? event) async {
    if (!_platform.canUseForegroundTask) return;
    final running = await _platform.isRunningService;
    // Disposed while checking: never start a service nothing will stop.
    if (_disposed) return;
    if (!running) await _platform.startService();

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

      await _platform.updateNotification(
        title: event.title,
        text: minutesLeft.isNegative
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
    _notificationTimer?.cancel();
    _notificationTimer = null;

    if (_platform.canUseForegroundTask) {
      try {
        if (await _platform.isRunningService) {
          await _platform.stopService();
        }
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error stopping background service',
        );
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_enqueue(_endBackgroundMode));
  }
}
