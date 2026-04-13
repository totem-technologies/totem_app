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
      return const PermissionsState();
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
      return const PermissionsState();
    }
  }

  Future<void> refreshStatuses() async {
    try {
      final statuses = await currentStatuses;
      if (!ref.mounted) return;
      state = AsyncValue.data(statuses);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to refresh permission statuses',
      );
      if (!ref.mounted) return;
      state = const AsyncValue.data(PermissionsState());
    }
  }

  Future<void> requestPermissions() async {
    try {
      final current = _currentOrDefault;
      final statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.notification,
      ].request();
      if (!ref.mounted) return;
      state = AsyncValue.data(
        current.copyWith(
          cameraStatus: statuses[Permission.camera] ?? current.cameraStatus,
          microphoneStatus:
              statuses[Permission.microphone] ?? current.microphoneStatus,
          notificationStatus:
              statuses[Permission.notification] ?? current.notificationStatus,
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
    final current = _currentOrDefault;
    try {
      final status = await Permission.camera.request();
      if (!ref.mounted) return;
      state = AsyncValue.data(current.copyWith(cameraStatus: status));

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
      if (!ref.mounted) return;
      state = AsyncValue.data(current);
    }
  }

  Future<void> requestMicrophone() async {
    final current = _currentOrDefault;
    try {
      final status = await Permission.microphone.request();
      if (!ref.mounted) return;
      state = AsyncValue.data(current.copyWith(microphoneStatus: status));

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
      if (!ref.mounted) return;
      state = AsyncValue.data(current);
    }
  }

  Future<void> requestNotification() async {
    final current = _currentOrDefault;
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

      if (!ref.mounted) return;
      state = AsyncValue.data(current.copyWith(notificationStatus: status));
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request notification permission',
      );
      if (!ref.mounted) return;
      state = AsyncValue.data(current);
    }
  }
}
