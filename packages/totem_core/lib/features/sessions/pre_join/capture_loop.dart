import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/pre_join/capture.dart';

/// Brings each device to what's wanted, one step at a time.
///
/// The single place the pre-join preview starts and stops devices. It runs
/// [nextEffect] for each device until nothing is left to do, and never runs
/// two steps at once, so a permission change and a user action arriving
/// together share one capture instead of racing.
class CaptureLoop {
  new({
    required this.start,
    required this.stop,
    required this.isOn,
    required this.permissionOf,
    required this.platform,
    this.available,
    this.onChanged,
  });

  /// Starts capturing a device, returning why it failed, or null.
  final Future<CaptureFailure?> Function(MediaKind kind) start;
  final Future<void> Function(MediaKind kind) stop;
  final bool Function(MediaKind kind) isOn;
  final MediaPermission Function(MediaKind kind) permissionOf;
  final PlatformInfo Function() platform;

  /// Whether the owner can start a device right now. True when omitted.
  final bool Function(MediaKind kind)? available;

  /// Called whenever an intent or a device's starting state changes.
  final VoidCallback? onChanged;

  final Map<MediaKind, DeviceIntent> _intents = {
    for (final kind in MediaKind.values) kind: const DeviceIntent(),
  };
  final _starting = <MediaKind>{};
  Future<void>? _running;
  bool _again = false;
  bool _closed = false;

  DeviceIntent intentOf(MediaKind kind) => _intents[kind]!;

  bool isStarting(MediaKind kind) => _starting.contains(kind);

  /// Whether no step is running or queued.
  bool get isSettled => _running == null;

  /// Completes once the steps running now have finished, without taking any
  /// new ones.
  Future<void> get idle => _running ?? Future<void>.value();

  void setIntent(MediaKind kind, DeviceIntent intent) {
    if (_intents[kind] == intent) return;
    _intents[kind] = intent;
    onChanged?.call();
  }

  /// Wants [kind] on and resolves with its intent once every step has run:
  /// its problem says whether it works.
  Future<DeviceIntent> turnOn(MediaKind kind) async {
    setIntent(kind, wantOn(intentOf(kind)));
    await run();
    return intentOf(kind);
  }

  Future<void> turnOff(MediaKind kind) {
    setIntent(kind, wantOff(intentOf(kind)));
    return run();
  }

  /// [kind] stopped capturing on its own; it stays off until turned on.
  void lose(MediaKind kind) => setIntent(kind, afterLoss(intentOf(kind)));

  /// Runs every step that's due. A call made while steps run schedules
  /// another pass, so the result reflects the latest inputs.
  Future<void> run() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _runUntilSettled().whenComplete(() {
      _running = null;
      onChanged?.call();
    });
  }

  /// Stops taking steps, such as once the devices are handed over.
  void close() => _closed = true;

  Future<void> _runUntilSettled() async {
    do {
      _again = false;
      for (final kind in MediaKind.values) {
        await _settle(kind);
      }
    } while (_again && !_closed);
  }

  Future<void> _settle(MediaKind kind) async {
    // One start and one stop per pass: a start that reports success without
    // the device coming on mustn't be retried forever.
    var started = false;
    var stopped = false;
    while (!_closed) {
      final effect = nextEffect(
        intentOf(kind),
        isOn: isOn(kind),
        permission: () => permissionOf(kind),
        platform: platform(),
        available: available?.call(kind) ?? true,
      );
      switch (effect) {
        case CaptureEffect.none:
          return;
        case CaptureEffect.start:
          if (started) return;
          started = true;
          _starting.add(kind);
          onChanged?.call();
          CaptureFailure? failure;
          try {
            failure = await start(kind);
          } catch (error, stackTrace) {
            ErrorHandler.logError(
              error,
              stackTrace: stackTrace,
              message: 'Failed to start ${kind.name}',
            );
            failure = const DeviceFailed(DeviceProblem.failed);
          } finally {
            _starting.remove(kind);
          }
          setIntent(kind, afterStart(intentOf(kind), failure));
          onChanged?.call();
        case CaptureEffect.stop:
          if (stopped) return;
          stopped = true;
          try {
            await stop(kind);
          } catch (error, stackTrace) {
            ErrorHandler.logError(
              error,
              stackTrace: stackTrace,
              message: 'Failed to stop ${kind.name}',
            );
          }
          onChanged?.call();
      }
    }
  }
}
