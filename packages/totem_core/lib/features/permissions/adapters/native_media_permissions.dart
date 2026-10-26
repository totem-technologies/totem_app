import 'package:permission_handler/permission_handler.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/classify.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

/// iOS and Android, through `permission_handler`.
class NativeMediaPermissions implements MediaPermissionAdapter {
  const NativeMediaPermissions(this.platform);

  final PlatformInfo platform;

  Permission _permission(MediaKind kind) => switch (kind) {
    MediaKind.camera => Permission.camera,
    MediaKind.microphone => Permission.microphone,
  };

  @override
  Future<MediaPermission?> query(MediaKind kind) async =>
      permissionFromStatus(await _permission(kind).status);

  @override
  Future<MediaPermission?> request(MediaKind kind) async =>
      permissionFromRequestResult(await _permission(kind).request(), platform);

  @override
  Future<bool> openSettings() => openAppSettings();

  @override
  Future<bool> hasDevice(MediaKind kind) async => true;

  // Native permissions only change while the app is in the background, and
  // the controller refreshes on resume.
  @override
  Stream<void> get changes => const Stream.empty();

  @override
  void dispose() {}
}
