/// Pure decisions over [MediaPermission] and [DeviceProblem]: who may join,
/// how to recover, when to capture, and how to combine a permission query
/// with what the app already learned.
///
/// IDs in comments refer to `specs/permissions.md`.
library;

import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

enum JoinReadiness {
  /// Permissions haven't been queried yet, or the preview is still starting.
  checking,

  /// The microphone may be used. The camera never affects this (X3).
  ready,

  /// The microphone can't be used; show its recovery action (X4).
  microphoneNeeded,
}

/// Whether the user may join.
///
/// [permissions] is null until the first permission query completes, so a
/// slow query can't be mistaken for a refusal (X1). Joining needs microphone
/// permission and a microphone that isn't failing, not an open microphone:
/// a user who turned it off joins muted.
JoinReadiness joinReadiness({
  required MediaPermissions? permissions,
  required DeviceProblem? microphoneProblem,
  required bool mediaSettled,
}) {
  if (permissions == null || !mediaSettled) return JoinReadiness.checking;
  return permissions.microphone == MediaPermission.granted &&
          microphoneProblem == null
      ? JoinReadiness.ready
      : JoinReadiness.microphoneNeeded;
}

/// The single way the UI offers to get a device working.
///
/// A definite refusal comes first: a device that stopped because its
/// permission was revoked shows how to allow it again, not how to reconnect
/// it (X13). Otherwise a device problem comes before an unknown permission,
/// since a browser that got as far as the device has already allowed it.
RecoveryAction recoveryFor(
  MediaPermission permission,
  DeviceProblem? problem,
  PlatformInfo platform,
) => switch (permission) {
  MediaPermission.granted ||
  MediaPermission.unknown when problem != null => RecoveryAction.retry,
  MediaPermission.granted => RecoveryAction.none,
  MediaPermission.unknown || MediaPermission.denied => RecoveryAction.request,
  MediaPermission.blocked => switch (platform) {
    // Native platforms won't show the prompt again (I2, A2).
    IosApp() || AndroidApp() => RecoveryAction.openAppSettings,
    WebPlatform() => RecoveryAction.showBrowserSiteSettings,
    OtherPlatform() => RecoveryAction.explainUnsupported,
  },
  MediaPermission.blockedBySystem => switch (platform) {
    // Only browsers can be blocked by the OS around them (WC3, WF4).
    WebPlatform() => RecoveryAction.showSystemPrivacySettings,
    IosApp() || AndroidApp() => RecoveryAction.openAppSettings,
    OtherPlatform() => RecoveryAction.explainUnsupported,
  },
  MediaPermission.restricted => RecoveryAction.explainRestricted,
  MediaPermission.unsupported => switch (platform) {
    WebPlatform(inAppBrowser: true) => RecoveryAction.openInBrowser,
    _ => RecoveryAction.explainUnsupported,
  },
};

/// Whether a device control should flag that something needs fixing.
///
/// Not for states the OS can still prompt for: tapping the control asks.
bool needsAttention(
  MediaPermission? permission,
  DeviceProblem? problem,
  PlatformInfo platform,
) {
  if (permission == null) return false;
  final action = recoveryFor(permission, problem, platform);
  return action != RecoveryAction.none && action != RecoveryAction.request;
}

/// Whether capture may start without the user asking for it.
///
/// Native capture shows the OS prompt itself, so it waits for a grant from
/// the user instead of prompting by itself (X2). On web, capture is the
/// request (WS2), so it goes ahead unless it's already known to fail.
bool capturesAllowed(MediaPermission permission, PlatformInfo platform) =>
    switch (platform) {
      IosApp() || AndroidApp() => permission == MediaPermission.granted,
      WebPlatform() => switch (permission) {
        MediaPermission.blocked ||
        MediaPermission.blockedBySystem ||
        MediaPermission.restricted ||
        MediaPermission.unsupported => false,
        MediaPermission.unknown ||
        MediaPermission.granted ||
        MediaPermission.denied => true,
      },
      OtherPlatform() => true,
    };

enum UserCaptureStep {
  /// Turn the device on; capture says whether it works.
  capture,

  /// Show the OS prompt first, then turn it on if it was granted.
  requestFirst,

  /// Capture can't succeed; show the recovery action instead.
  recover,
}

/// What happens when the user turns a device on.
UserCaptureStep userCaptureStep(
  MediaPermission permission,
  PlatformInfo platform,
) => switch (platform) {
  IosApp() || AndroidApp() => switch (permission) {
    MediaPermission.unknown ||
    MediaPermission.denied => UserCaptureStep.requestFirst,
    MediaPermission.granted => UserCaptureStep.capture,
    // The OS won't prompt again (X7).
    MediaPermission.blocked ||
    MediaPermission.blockedBySystem ||
    MediaPermission.restricted ||
    MediaPermission.unsupported => UserCaptureStep.recover,
  },
  // Queries can be stale and capture is the request, so a user action
  // always tries again (WS1, WF2).
  WebPlatform() || OtherPlatform() => UserCaptureStep.capture,
};

/// Whether a refusal returned by the OS prompt still needs explaining.
///
/// Elsewhere the refusal is the user's answer at the prompt. Android stops
/// prompting after a second refusal while its status still says it may ask,
/// so after a relaunch the request returns refused without a prompt (A2).
/// The app can't tell that from a refusal just made, so both get the fix.
bool explainsRefusal(MediaPermission result, PlatformInfo platform) =>
    switch (platform) {
      AndroidApp() => result == MediaPermission.blocked,
      IosApp() || WebPlatform() || OtherPlatform() => false,
    };

/// Combines a fresh permission [query] with the [current] permission.
///
/// Queries are hints: they go stale (WS1), report per-device grants as global
/// (WF3), can't see the Android privacy toggles (A5), and forget Android
/// refusals (A2). So a query that matches [previousQuery] never overrides a
/// permission learned from capture or a request. A query that changed means
/// something outside the app changed, such as Settings, the browser's site
/// settings or an expired one-time grant (X5, X12, WC1), so it wins.
MediaPermission reconcileQuery({
  required MediaPermission current,
  required MediaPermission? previousQuery,
  required MediaPermission query,
}) {
  if (previousQuery == null) {
    return current == MediaPermission.unknown ? query : current;
  }
  return query == previousQuery ? current : query;
}
