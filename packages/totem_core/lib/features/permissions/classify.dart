/// Pure mappings from what platforms report to [MediaPermission] and
/// [CaptureFailure].
///
/// Every platform quirk that changes what a status or error means is decided
/// here, and nowhere else. IDs in comments refer to `specs/permissions.md`.
library;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

/// Maps a native permission status query.
///
/// The status alone can't tell "never asked" from "refused": iOS reports
/// never-asked as `denied` (I1), and Android reports `denied` before the first
/// request and after any number of refusals (A2). Both become
/// [MediaPermission.unknown]; a remembered request result takes precedence
/// through `reconcileQuery`.
MediaPermission permissionFromStatus(PermissionStatus status) =>
    switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => MediaPermission.granted,
      PermissionStatus.restricted => MediaPermission.restricted,
      PermissionStatus.permanentlyDenied => MediaPermission.blocked,
      PermissionStatus.denied => MediaPermission.unknown,
    };

/// Maps the result of a native permission request.
MediaPermission permissionFromRequestResult(
  PermissionStatus status,
  PlatformInfo platform,
) => switch ((status, platform)) {
  // Android: refused once, or dismissed with back (A1, A3). May ask again.
  (PermissionStatus.denied, AndroidApp()) => MediaPermission.denied,
  // iOS reports refusals as permanentlyDenied (I2), so a plain denied means
  // no prompt was answered.
  (PermissionStatus.denied, _) => MediaPermission.unknown,
  _ => permissionFromStatus(status),
};

/// Maps a `navigator.permissions.query` state (W4).
///
/// Chrome reports an expired one-time grant as `prompt` (WC1).
MediaPermission permissionFromWebState(String state) => switch (state) {
  'granted' => MediaPermission.granted,
  'denied' => MediaPermission.blocked,
  _ => MediaPermission.unknown,
};

/// Chromium's pre-standard error names, and what they became.
const _legacyErrorNames = {
  'PermissionDeniedError': 'NotAllowedError',
  'PermissionDismissedError': 'NotAllowedError',
  'DevicesNotFoundError': 'NotFoundError',
  'TrackStartError': 'NotReadableError',
  'ConstraintNotSatisfiedError': 'OverconstrainedError',
};

final _errorNamePattern = RegExp(
  r'\b(NotAllowedError|NotFoundError|NotReadableError|AbortError|'
  'OverconstrainedError|SecurityError|PermissionDeniedError|'
  'PermissionDismissedError|DevicesNotFoundError|TrackStartError|'
  r'ConstraintNotSatisfiedError)\b',
);

/// Extracts the standard DOMException name from a capture error.
///
/// Every capture path reports errors as text. iOS sends `NotAllowedError`
/// and `NotFoundError`, Android sends `getUserMedia(): DOMException,
/// NotAllowedError`, and a media SDK may wrap the browser's error in its own
/// exception's message.
String? captureErrorName(Object error) {
  final match = _errorNamePattern.firstMatch(_describe(error));
  if (match == null) return null;
  final name = match.group(1)!;
  return _legacyErrorNames[name] ?? name;
}

/// Classifies a failed capture, or returns null when the error isn't a known
/// failure and should be reported as unexpected.
///
/// [deviceListed] is whether `enumerateDevices` lists a device of the kind
/// that failed. Firefox reports an OS-level block as `NotFoundError`, and a
/// listed device is the only way to tell it from a missing one (WF4).
CaptureFailure? classifyCaptureError(
  Object error,
  PlatformInfo platform, {
  bool deviceListed = false,
}) {
  final name = captureErrorName(error);
  return switch (platform) {
    // iOS refusals can only be undone in Settings (I2).
    IosApp() => switch (name) {
      'NotAllowedError' => const PermissionRefused(MediaPermission.blocked),
      'NotFoundError' => const DeviceFailed(DeviceProblem.notFound),
      // The audio session checks microphone access before capture, and says
      // so in words rather than a DOMException name.
      null when _isMicrophoneAccessRefusal(_describe(error)) =>
        const PermissionRefused(MediaPermission.blocked),
      // Asked while a call or Siri had the app in the background (I7).
      null when _describe(error).contains('app is not in the foreground') =>
        const DeviceFailed(DeviceProblem.failed),
      _ => null,
    },
    // Android may ask again after a single refusal (A1).
    AndroidApp() => switch (name) {
      'NotAllowedError' => const PermissionRefused(MediaPermission.denied),
      'NotFoundError' => const DeviceFailed(DeviceProblem.notFound),
      _ => null,
    },
    WebPlatform() => _classifyWebError(
      name,
      _describe(error),
      platform,
      deviceListed: deviceListed,
    ),
    OtherPlatform() => null,
  };
}

CaptureFailure? _classifyWebError(
  String? name,
  String message,
  WebPlatform platform, {
  required bool deviceListed,
}) {
  // Firefox on iOS is WebKit underneath, so it reports errors like Safari.
  final isFirefox =
      platform.browser == WebBrowser.firefox && platform.os != HostOs.ios;
  return switch (name) {
    // The user never saw a prompt (WS5).
    'NotAllowedError' when platform.inAppBrowser => const PermissionRefused(
      MediaPermission.unsupported,
    ),
    // Dismissed without an answer, so it can be asked again (WC2).
    'NotAllowedError' when _isDismissal(message) => const PermissionRefused(
      MediaPermission.unknown,
    ),
    'NotAllowedError' when message.contains('by system') =>
      const PermissionRefused(MediaPermission.blockedBySystem),
    // Firefox's temporary block and every browser's site block (W3, WF2).
    'NotAllowedError' => const PermissionRefused(MediaPermission.blocked),
    'NotFoundError' when isFirefox && deviceListed => const PermissionRefused(
      MediaPermission.blockedBySystem,
    ),
    'NotFoundError' => const DeviceFailed(DeviceProblem.notFound),
    // Firefox: OS block. Chrome and Edge: in use, or a Windows privacy block,
    // which they can't tell apart (WC4).
    'NotReadableError' when isFirefox => const PermissionRefused(
      MediaPermission.blockedBySystem,
    ),
    'NotReadableError' => const DeviceFailed(DeviceProblem.inUse),
    // Firefox: in use (WF5).
    'AbortError' => const DeviceFailed(DeviceProblem.inUse),
    // The selected device is gone.
    'OverconstrainedError' => const DeviceFailed(DeviceProblem.notFound),
    'SecurityError' => const PermissionRefused(MediaPermission.unsupported),
    // Insecure contexts have no navigator.mediaDevices (W1).
    null when _isMissingMediaDevices(message) => const PermissionRefused(
      MediaPermission.unsupported,
    ),
    _ => null,
  };
}

bool _isMicrophoneAccessRefusal(String message) =>
    message.contains('Microphone permission is not granted') ||
    message.contains('Microphone permission was denied');

bool _isDismissal(String message) =>
    message.contains('dismissed') || message.contains('PermissionDismissed');

bool _isMissingMediaDevices(String message) =>
    message.contains('TypeError') &&
    (message.contains('mediaDevices') || message.contains('getUserMedia'));

String _describe(Object error) => switch (error) {
  PlatformException(:final code, :final message) => '$code: $message',
  _ => error.toString(),
};
