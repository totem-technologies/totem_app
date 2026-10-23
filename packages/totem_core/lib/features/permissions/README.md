# Permissions module

Camera, microphone and notification permission for the app. The behaviour it
implements, and the corner cases behind it, are in `specs/permissions.md`;
code comments cite that document's IDs (X1, A2, WF4, ...).

## Two kinds of state

What's wrong with a device is one of two things, kept apart so neither can
overwrite the other:

- **Permission** (`MediaPermission`): whether the platform lets the app use
  the device. Owned by `MediaPermissionController`, one for the app.
- **Device problem** (`DeviceProblem`): why an allowed device isn't working
  (busy, missing, failed, stopped). Owned by whoever captures the device: the
  pre-join preview or the session.

What the user is shown (`recoveryFor`, `recoveryContent`) is a pure function
of both, plus the platform.

## The boundary with capture

This module never captures, and knows nothing of LiveKit or sessions (audit
rule 5). Whoever captures a device hands it a `MediaControl`: the device's
problem, and a `turnOn` that captures and returns a `TurnOnOutcome`. The
contract is small:

- Before capturing, `turnOnMedia` takes the step `userCaptureStep` says:
  capture, ask the OS first, or show recovery.
- The owner captures, and reports each outcome with `recordCaptureSuccess`
  or `recordCaptureFailure`, which classifies the error and learns the
  permission from it. On web capture is the request, so outcomes are the
  only reliable source of permission state.
- `turnOnMedia` then explains a failure that needs the user (`TurnOnFailed`).
  A `TurnOnSkipped` is the owner's own business, such as a hidden tab or a
  room that couldn't take the track, and the owner tells the user itself.

The two owners are deliberately different:

- The **pre-join preview** (`sessions/pre_join/`) captures by itself: a
  device waiting for a grant starts once it's granted. It runs a
  `CaptureLoop` over a pure `DeviceIntent` per device.
- The **session** (`SessionDeviceController`) only captures on a user
  action, with plain LiveKit commands run one at a time per device. Its
  rules (the keeper, the room's connection) and LiveKit's quirks stay there.

So the preview and the session ask, capture and explain the same way, while
each keeps its own capture mechanics.

## Files

| File | Role |
|---|---|
| `model.dart` | `MediaKind`, `MediaPermission`, `DeviceProblem`, `CaptureFailure`, `RecoveryAction` |
| `platform_info*.dart` | Sealed `PlatformInfo`; the only place that inspects the platform or browser |
| `classify.dart` | Pure: platform statuses and capture errors → permission or device problem |
| `policy.dart` | Pure: join readiness, recovery, when capture may start, query reconciling |
| `media_permission_controller.dart` | Permission state; queries, requests, capture outcomes; reports capture errors |
| `media_control.dart` | A device the user can turn on, wherever it's captured, and `TurnOnOutcome` |
| `notification_permissions.dart` | Notification permission interface; no-op default |
| `adapters/` | Platform permission APIs: native (`permission_handler`) and web (`navigator.permissions`) |
| `ui/recovery_content.dart` | Pure: every piece of help copy, per situation and platform |
| `ui/recovery.dart` | `turnOnMedia`, `recoverMedia`, the recovery dialog and banner |
| `ui/priming_sheet.dart` | The native screen shown before the system prompt |

Capture mechanics stay with their owners: `PreJoinMediaController` (preview
tracks, Safari's one-at-a-time capture queue, the hidden-tab gate) and
`SessionDeviceController` with `LiveKitLocalMedia` (published tracks, which
on web also detects a capture that ends on its own mid-call; native WebRTC
never reports it; and `MediaPublishException` for a track the room couldn't
take).

## Adding a platform or browser

Add a case to `PlatformInfo` or `WebBrowser`. Every decision that branches on
the platform is an exhaustive `switch`, so the compiler lists each place that
needs an answer, help copy included.

## Audit rules

`test/features/permissions/audit_test.dart` scans the non-comment source of
`totem_core`, `totem_app` and `totem_web` and fails when:

1. `permission_handler` is imported outside `adapters/native_media_permissions.dart`
   and `classify.dart` (which uses only its `PermissionStatus` type), or
   `navigator.permissions` is used outside `adapters/web_media_permissions.dart`.
2. Notification permission is requested anywhere but `totem_app`'s
   `FirebaseNotificationPermissions`, which overrides
   `notificationPermissionsProvider` in its `main.dart`; or any battery
   optimization API or manifest permission appears. `totem_core` and
   `totem_web` never depend on Firebase: the web plugin registrant registers
   every plugin in the dependency graph, so tree shaking can't remove it.
3. The user agent or touch points are read outside `platform_info*.dart`, or
   platform globals (`Platform.is*`, `defaultTargetPlatform`, `kIsWeb`) are
   read elsewhere in this module. `WebPlatform.os` is what the user agent
   reports (iPadOS Safari reports macOS); `hasTouchScreen` only orders help
   text.
4. This module calls `getUserMedia`: on web, capture is the permission
   request, and a second capture of a device mutes the first on WebKit.
5. This module imports anything outside itself but a short allowlist of
   shared UI and error reporting, or any capture package (LiveKit, WebRTC),
   counting relative and conditional imports; or an allowlisted file imports
   session code. Capture owners depend on it, never the reverse, so LiveKit
   changes stay out of permission logic. Error reporting does import LiveKit
   to describe its errors, but no LiveKit type reaches this module.
