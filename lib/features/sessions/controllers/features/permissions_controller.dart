import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  @override
  Future<PermissionsState> build() async {
    return currentStatuses;
  }

  Future<PermissionsState> get currentStatuses async {
    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;

    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    final notificationStatus = notifPermission == NotificationPermission.granted
        ? PermissionStatus.granted
        : PermissionStatus.denied;

    return PermissionsState(
      cameraStatus: camera,
      microphoneStatus: microphone,
      notificationStatus: notificationStatus,
    );
  }

  Future<void> refreshStatuses() async {
    state = AsyncValue.data(await currentStatuses);
  }

  Future<void> requestCamera() async {
    final status = await Permission.camera.request();
    state = AsyncValue.data(
      state.asData?.value.copyWith(cameraStatus: status) ??
          PermissionsState(cameraStatus: status),
    );
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> requestMicrophone() async {
    final status = await Permission.microphone.request();
    state = AsyncValue.data(
      state.asData?.value.copyWith(microphoneStatus: status) ??
          PermissionsState(microphoneStatus: status),
    );
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> requestNotification() async {
    final result = await FlutterForegroundTask.requestNotificationPermission();
    final status = result == NotificationPermission.granted
        ? PermissionStatus.granted
        : PermissionStatus.denied;
    state = AsyncValue.data(
      state.asData?.value.copyWith(notificationStatus: status) ??
          PermissionsState(notificationStatus: status),
    );
  }
}
