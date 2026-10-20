/// Pure rules for one pre-join preview device: what the user wants, what to
/// do next, and how each outcome changes that.
///
/// The preview keeps one [DeviceIntent] per device and runs [nextEffect]
/// until it says [CaptureEffect.none]. A permission change, a user action
/// and a capture outcome all just change the inputs, so capture only ever
/// starts from one place. IDs in comments refer to `specs/permissions.md`.
library;

import 'package:flutter/foundation.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/policy.dart';

@immutable
class DeviceIntent {
  const new({
    this.wanted = false,
    this.problem,
    this.refusedAs,
    this.retry = false,
  });

  /// Whether the device should be capturing.
  final bool wanted;

  /// Why the last capture didn't work, while the permission was fine. Cleared
  /// by the next successful capture or by turning the device off.
  final DeviceProblem? problem;

  /// The permission the platform refused the last capture with. Capture
  /// isn't retried on its own until the permission changes, so a dismissed
  /// browser prompt isn't shown again and again (WC2), while a grant from
  /// Settings or site settings restarts it (X5, X12).
  final MediaPermission? refusedAs;

  /// Try once more even if a query or an earlier problem says capture will
  /// fail, because the user asked: queries can be stale (WS1, WF2).
  final bool retry;

  @override
  bool operator ==(Object other) =>
      other is DeviceIntent &&
      other.wanted == wanted &&
      other.problem == problem &&
      other.refusedAs == refusedAs &&
      other.retry == retry;

  @override
  int get hashCode => Object.hash(wanted, problem, refusedAs, retry);

  @override
  String toString() =>
      'DeviceIntent(wanted: $wanted, problem: ${problem?.name}, '
      'refusedAs: ${refusedAs?.name}, retry: $retry)';
}

enum CaptureEffect { none, start, stop }

/// What to do next for one device.
///
/// [isOn] is whether it's capturing now. [available] is false while the
/// capture owner can't start it for its own reasons, such as a hidden
/// browser tab. [permission] is only read when deciding whether a wanted
/// device may start by itself, so stopping a device never depends on it.
CaptureEffect nextEffect(
  DeviceIntent intent, {
  required bool isOn,
  required MediaPermission Function() permission,
  required PlatformInfo platform,
  bool available = true,
}) {
  if (!intent.wanted) return isOn ? CaptureEffect.stop : CaptureEffect.none;
  if (isOn || !available) return CaptureEffect.none;
  if (intent.retry) return CaptureEffect.start;
  // A device problem waits for the user to try again (X9).
  if (intent.problem != null) return CaptureEffect.none;
  final current = permission();
  if (intent.refusedAs == current) return CaptureEffect.none;
  return capturesAllowed(current, platform)
      ? CaptureEffect.start
      : CaptureEffect.none;
}

/// The user turns the device on: capture is tried once even if a query or
/// an earlier failure says it won't work.
DeviceIntent wantOn(DeviceIntent intent) => DeviceIntent(
  wanted: true,
  problem: intent.problem,
  refusedAs: intent.refusedAs,
  retry: true,
);

/// The user turns the device off. Any earlier failure no longer matters.
DeviceIntent wantOff(DeviceIntent intent) => const DeviceIntent();

/// The outcome of a start: null when it's capturing. A device turned off
/// while it was starting stays cleanly off, whatever the start said.
DeviceIntent afterStart(DeviceIntent intent, CaptureFailure? failure) =>
    switch (failure) {
      _ when !intent.wanted => const DeviceIntent(),
      null => DeviceIntent(wanted: intent.wanted),
      // The permission explains it, and its change restarts capture.
      PermissionRefused(:final permission) => DeviceIntent(
        wanted: intent.wanted,
        refusedAs: permission,
      ),
      DeviceFailed(:final problem) => DeviceIntent(
        wanted: intent.wanted,
        problem: problem,
      ),
    };

/// A capture stopped on its own (X13, W9). It stays off until the user turns
/// it on again, so a device that's gone isn't captured again by itself.
DeviceIntent afterLoss(DeviceIntent intent) =>
    const DeviceIntent(problem: DeviceProblem.lost);
