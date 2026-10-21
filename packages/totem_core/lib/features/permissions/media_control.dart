import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:totem_core/features/permissions/model.dart';

/// What turning a device on came to.
@immutable
sealed class TurnOnOutcome {
  const TurnOnOutcome();
}

/// The device is capturing.
final class TurnedOn extends TurnOnOutcome {
  const TurnedOn();
}

/// Capture failed: the permission was refused or the device has a problem.
/// The permission state has already learned from it, and recovery explains
/// the fix.
final class TurnOnFailed extends TurnOnOutcome {
  const TurnOnFailed(this.failure);

  final CaptureFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TurnOnFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

/// The device's owner didn't capture it, for reasons of its own that it
/// shows the user itself, such as a hidden browser tab or a room that isn't
/// connected. There's nothing for recovery to explain.
final class TurnOnSkipped extends TurnOnOutcome {
  const TurnOnSkipped();
}

/// A device the user can turn on, wherever it's captured: the pre-join
/// preview or the session.
@immutable
class MediaControl {
  const MediaControl({
    required this.kind,
    required this.problem,
    required this.turnOn,
  });

  final MediaKind kind;

  /// The device's current problem, for widgets to watch.
  final ProviderListenable<DeviceProblem?> problem;

  /// Turns the device on, capturing it if needed, and resolves with how it
  /// went. Capture failures must already be recorded with the permission
  /// controller, so the permission state reflects them.
  final Future<TurnOnOutcome> Function() turnOn;
}
