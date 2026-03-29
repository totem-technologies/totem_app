import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permissions_controller.g.dart';

class PermissionsState {
  const PermissionsState({
    this.cameraStatus = PermissionStatus.denied,
    this.microphoneStatus = PermissionStatus.denied,
    this.notificationStatus = PermissionStatus.denied,
  });

  final PermissionStatus cameraStatus;
  final PermissionStatus microphoneStatus;
  final PermissionStatus notificationStatus;

  bool get requiredPermissionsGranted =>
      cameraStatus.isGranted && microphoneStatus.isGranted;

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
}

@riverpod
class PermissionsController extends _$PermissionsController {
  @override
  PermissionsState build() {
    refreshStatuses();
    return const PermissionsState();
  }

  Future<void> refreshStatuses() async {
    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;

    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    final notificationStatus = notifPermission == NotificationPermission.granted
        ? PermissionStatus.granted
        : PermissionStatus.denied;

    state = PermissionsState(
      cameraStatus: camera,
      microphoneStatus: microphone,
      notificationStatus: notificationStatus,
    );
  }

  Future<void> requestCamera() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    state = state.copyWith(cameraStatus: status);
  }

  Future<void> requestMicrophone() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    state = state.copyWith(microphoneStatus: status);
  }

  Future<void> requestNotification() async {
    final result =
        await FlutterForegroundTask.requestNotificationPermission();
    final status = result == NotificationPermission.granted
        ? PermissionStatus.granted
        : PermissionStatus.denied;
    state = state.copyWith(notificationStatus: status);
  }
}
