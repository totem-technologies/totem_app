import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/errors/error_handler.dart';

part 'permissions_controller.g.dart';

@immutable
class PermissionsState {
  const PermissionsState({
    this.cameraStatus = PermissionStatus.denied,
    this.microphoneStatus = PermissionStatus.denied,
    this.notificationStatus = PermissionStatus.denied,
  });

  final PermissionStatus cameraStatus;
  final PermissionStatus microphoneStatus;
  final PermissionStatus notificationStatus;

  bool get isCameraGranted => cameraStatus.isGranted;
  bool get isMicrophoneGranted => microphoneStatus.isGranted;
  bool get isNotificationGranted => notificationStatus.isGranted;

  bool get requiredPermissionsGranted => isCameraGranted && isMicrophoneGranted;

  PermissionsState copyWith({
    PermissionStatus? cameraStatus,
    PermissionStatus? microphoneStatus,
    PermissionStatus? notificationStatus,
  }) {
    return PermissionsState(
      cameraStatus: cameraStatus ?? this.cameraStatus,
      microphoneStatus: microphoneStatus ?? this.microphoneStatus,
      notificationStatus: notificationStatus ?? this.notificationStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionsState &&
        other.cameraStatus == cameraStatus &&
        other.microphoneStatus == microphoneStatus &&
        other.notificationStatus == notificationStatus;
  }

  @override
  int get hashCode =>
      cameraStatus.hashCode ^
      microphoneStatus.hashCode ^
      notificationStatus.hashCode;
}

@riverpod
class PermissionsController extends _$PermissionsController {
  PermissionsState get _currentOrDefault =>
      state.asData?.value ?? const PermissionsState();

  @override
  Future<PermissionsState> build() async {
    try {
      return currentStatuses;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to build permissions state',
      );
      return _currentOrDefault;
    }
  }

  Future<PermissionsState> get currentStatuses async {
    try {
      final camera = await Permission.camera.status;
      final microphone = await Permission.microphone.status;

      PermissionStatus notificationStatus = PermissionStatus.denied;
      if (!(kIsWeb || kIsWasm)) {
        final notificationsPermission =
            await FlutterForegroundTask.checkNotificationPermission();
        notificationStatus =
            notificationsPermission == NotificationPermission.granted
            ? PermissionStatus.granted
            : PermissionStatus.denied;
      } else {
        notificationStatus = await Permission.notification.status;
      }
      return PermissionsState(
        cameraStatus: camera,
        microphoneStatus: microphone,
        notificationStatus: notificationStatus,
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to fetch current permission statuses',
      );
      return _currentOrDefault;
    }
  }

  Future<void> refreshStatuses() async {
    try {
      state = AsyncValue.data(await currentStatuses);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to refresh permission statuses',
      );
      state = AsyncValue.data(_currentOrDefault);
    }
  }

  Future<void> requestPermissions() async {
    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.notification,
      ].request();
      state = AsyncValue.data(
        _currentOrDefault.copyWith(
          cameraStatus:
              statuses[Permission.camera] ?? _currentOrDefault.cameraStatus,
          microphoneStatus:
              statuses[Permission.microphone] ??
              _currentOrDefault.microphoneStatus,
          notificationStatus:
              statuses[Permission.notification] ??
              _currentOrDefault.notificationStatus,
        ),
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request permissions',
      );
    }
  }

  Future<void> requestCamera() async {
    try {
      final status = await Permission.camera.request();
      state = AsyncValue.data(_currentOrDefault.copyWith(cameraStatus: status));

      if (status.isPermanentlyDenied) {
        try {
          await openAppSettings();
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Failed to open app settings after camera denial',
          );
        }
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request camera permission',
      );
      state = AsyncValue.data(_currentOrDefault);
    }
  }

  Future<void> requestMicrophone() async {
    try {
      final status = await Permission.microphone.request();
      state = AsyncValue.data(
        _currentOrDefault.copyWith(microphoneStatus: status),
      );

      if (status.isPermanentlyDenied) {
        try {
          await openAppSettings();
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Failed to open app settings after microphone denial',
          );
        }
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request microphone permission',
      );
      state = AsyncValue.data(_currentOrDefault);
    }
  }

  Future<void> requestNotification() async {
    try {
      PermissionStatus status;
      if (kIsWeb || kIsWasm) {
        status = await Permission.notification.request();
      } else {
        final result =
            await FlutterForegroundTask.requestNotificationPermission();
        status = result == NotificationPermission.granted
            ? PermissionStatus.granted
            : PermissionStatus.denied;
      }

      state = AsyncValue.data(
        _currentOrDefault.copyWith(notificationStatus: status),
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request notification permission',
      );
      state = AsyncValue.data(_currentOrDefault);
    }
  }
}
