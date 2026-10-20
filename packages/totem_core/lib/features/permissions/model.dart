import 'package:flutter/foundation.dart';

/// A capture device that needs permission.
enum MediaKind { camera, microphone }

/// Whether the platform lets the app use one [MediaKind].
///
/// Only what the platform allows: why an allowed device isn't working is a
/// [DeviceProblem], kept by whoever captures it. The cases behind each value
/// are catalogued in `specs/permissions.md`.
enum MediaPermission {
  /// Never asked, dismissed without an answer, or a one-time grant expired.
  unknown,

  /// Capture is allowed.
  granted,

  /// Refused, and the app may ask again. Android after a single refusal.
  denied,

  /// Refused. Only the app's Settings page or the browser's site settings
  /// can change it.
  blocked,

  /// The operating system blocks the browser itself. Web only.
  blockedBySystem,

  /// Disallowed by device policy, such as Screen Time or MDM.
  restricted,

  /// This platform can't capture at all, such as an insecure context or an
  /// in-app browser.
  unsupported,
}

@immutable
class MediaPermissions {
  const new({
    this.camera = MediaPermission.unknown,
    this.microphone = MediaPermission.unknown,
  });

  final MediaPermission camera;
  final MediaPermission microphone;

  MediaPermission operator [](MediaKind kind) => switch (kind) {
    MediaKind.camera => camera,
    MediaKind.microphone => microphone,
  };

  MediaPermissions withPermission(MediaKind kind, MediaPermission permission) =>
      switch (kind) {
        MediaKind.camera => MediaPermissions(
          camera: permission,
          microphone: microphone,
        ),
        MediaKind.microphone => MediaPermissions(
          camera: camera,
          microphone: permission,
        ),
      };

  @override
  bool operator ==(Object other) =>
      other is MediaPermissions &&
      other.camera == camera &&
      other.microphone == microphone;

  @override
  int get hashCode => Object.hash(camera, microphone);

  @override
  String toString() =>
      'MediaPermissions(camera: ${camera.name}, '
      'microphone: ${microphone.name})';
}

/// Why a device the platform allows isn't working.
enum DeviceProblem {
  /// Another app or tab is using it.
  inUse,

  /// There is no device of this kind, or the selected one is gone.
  notFound,

  /// Capture failed with an error that isn't a known failure.
  failed,

  /// It was capturing and stopped on its own, such as when it was unplugged
  /// or its permission was revoked mid-call.
  lost,
}

/// Why starting a capture failed.
@immutable
sealed class CaptureFailure {
  const new();

  /// The device's problem, or null when the permission explains the failure.
  DeviceProblem? get problem;
}

/// The platform refused: the permission explains it.
final class PermissionRefused extends CaptureFailure {
  const new(this.permission);

  final MediaPermission permission;

  @override
  DeviceProblem? get problem => null;

  @override
  bool operator ==(Object other) =>
      other is PermissionRefused && other.permission == permission;

  @override
  int get hashCode => permission.hashCode;

  @override
  String toString() => 'PermissionRefused(${permission.name})';
}

/// The permission was fine, but the device didn't work.
final class DeviceFailed extends CaptureFailure {
  const new(this.problem);

  @override
  final DeviceProblem problem;

  @override
  bool operator ==(Object other) =>
      other is DeviceFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;

  @override
  String toString() => 'DeviceFailed(${problem.name})';
}

/// What the UI offers the user to get a device working.
enum RecoveryAction {
  /// Nothing to fix.
  none,

  /// Ask again: the OS prompt on native, a new capture on web.
  request,

  /// Open this app's page in the system Settings app.
  openAppSettings,

  /// Show steps for the browser's site settings, then reload.
  showBrowserSiteSettings,

  /// Show steps for the operating system's privacy settings, which block the
  /// browser.
  showSystemPrivacySettings,

  /// Explain that device policy disallows it. The user can't fix it here.
  explainRestricted,

  /// Ask the user to free or connect the device, then try again.
  retry,

  /// Suggest opening the page in the system browser.
  openInBrowser,

  /// Explain that this page can't use the camera or microphone here.
  explainUnsupported,
}
