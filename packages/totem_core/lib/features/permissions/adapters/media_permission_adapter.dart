import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/permissions/adapters/native_media_permissions.dart';
import 'package:totem_core/features/permissions/adapters/web_media_permissions_stub.dart'
    if (dart.library.js_interop) 'package:totem_core/features/permissions/adapters/web_media_permissions.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

part 'media_permission_adapter.g.dart';

/// A platform's camera and microphone permission APIs.
///
/// Adapters only translate platform calls; every decision about what a result
/// means lives in `classify.dart` and `policy.dart`.
abstract interface class MediaPermissionAdapter {
  /// The permission as the platform reports it, or null when the platform
  /// can't say, such as Firefox before 132 (W4).
  Future<MediaPermission?> query(MediaKind kind);

  /// Shows the OS prompt and returns its result. Null on web, where capture
  /// itself is the request (WS2).
  Future<MediaPermission?> request(MediaKind kind);

  /// Opens this app's page in system Settings. False when there is none.
  Future<bool> openSettings();

  /// Whether a device of [kind] is listed. Firefox reports an OS-level block
  /// as a missing device, and this tells the two apart (WF4).
  Future<bool> hasDevice(MediaKind kind);

  /// Fires when the platform reports a permission change on its own.
  Stream<void> get changes;

  void dispose();
}

@Riverpod(keepAlive: true)
MediaPermissionAdapter mediaPermissionAdapter(Ref ref) {
  final platform = ref.watch(platformInfoProvider);
  final adapter = switch (platform) {
    IosApp() || AndroidApp() => NativeMediaPermissions(platform),
    WebPlatform() => createWebMediaPermissions(),
    OtherPlatform() => const UnmanagedMediaPermissions(),
  };
  ref.onDispose(adapter.dispose);
  return adapter;
}

/// Platforms without a permission model of their own, such as desktop builds
/// and the test host. Access is assumed, and capture outcomes decide.
class UnmanagedMediaPermissions implements MediaPermissionAdapter {
  const UnmanagedMediaPermissions();

  @override
  Future<MediaPermission?> query(MediaKind kind) async =>
      MediaPermission.granted;

  @override
  Future<MediaPermission?> request(MediaKind kind) async =>
      MediaPermission.granted;

  @override
  Future<bool> openSettings() async => false;

  @override
  Future<bool> hasDevice(MediaKind kind) async => true;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  void dispose() {}
}
