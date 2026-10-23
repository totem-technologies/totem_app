import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/pre_join/capture.dart';
import 'package:totem_core/features/sessions/pre_join/capture_loop.dart';

/// Devices whose captures complete when the test says so.
class _Devices {
  final on = <MediaKind>{};
  final starts = <MediaKind>[];
  final stops = <MediaKind>[];
  final pending = <MediaKind, Completer<CaptureFailure?>>{};
  final Map<MediaKind, MediaPermission> permissions = {
    MediaKind.camera: MediaPermission.granted,
    MediaKind.microphone: MediaPermission.granted,
  };
  bool available = true;
  int changes = 0;

  late final loop = CaptureLoop(
    start: (kind) async {
      starts.add(kind);
      final failure = await (pending[kind] = Completer()).future;
      if (failure == null) on.add(kind);
      return failure;
    },
    stop: (kind) async {
      stops.add(kind);
      on.remove(kind);
    },
    isOn: on.contains,
    permissionOf: (kind) => permissions[kind]!,
    platform: () => const IosApp(),
    available: (_) => available,
    onChanged: () => changes++,
  );

  void finish(MediaKind kind, [CaptureFailure? failure]) =>
      pending.remove(kind)!.complete(failure);
}

void main() {
  test('turnOn resolves with the outcome of the capture', () async {
    final devices = _Devices();
    final turnOn = devices.loop.turnOn(MediaKind.camera);
    await pumpEventQueue();
    devices.finish(MediaKind.camera, const DeviceFailed(DeviceProblem.inUse));

    check((await turnOn).problem).equals(DeviceProblem.inUse);
    check(devices.on).isEmpty();
  });

  test(
    'X2: a grant and a tap together capture once, and both wait for it',
    () async {
      final devices = _Devices()
        ..permissions[MediaKind.microphone] = MediaPermission.unknown;
      devices.loop.setIntent(
        MediaKind.microphone,
        const DeviceIntent(wanted: true),
      );
      await devices.loop.run();
      check(devices.starts).isEmpty();

      // The grant wakes the loop, and the user's tap lands while it starts.
      devices.permissions[MediaKind.microphone] = MediaPermission.granted;
      final woken = devices.loop.run();
      await pumpEventQueue();
      var tapSettled = false;
      final tap = devices.loop
          .turnOn(MediaKind.microphone)
          .whenComplete(() => tapSettled = true);
      await pumpEventQueue();
      check(tapSettled).isFalse();

      devices.finish(MediaKind.microphone);
      await Future.wait([woken, tap]);
      check(devices.starts).deepEquals([MediaKind.microphone]);
      check(devices.on).deepEquals({MediaKind.microphone});
    },
  );

  test('turning off during a start stops once the start lands', () async {
    final devices = _Devices();
    final turnOn = devices.loop.turnOn(MediaKind.camera);
    await pumpEventQueue();
    final turnOff = devices.loop.turnOff(MediaKind.camera);
    devices.finish(MediaKind.camera);
    await Future.wait([turnOn, turnOff]);

    check(devices.stops).deepEquals([MediaKind.camera]);
    check(devices.on).isEmpty();
  });

  test('on, off and on again while starting ends on', () async {
    final devices = _Devices();
    final first = devices.loop.turnOn(MediaKind.camera);
    await pumpEventQueue();
    unawaited(devices.loop.turnOff(MediaKind.camera));
    final last = devices.loop.turnOn(MediaKind.camera);
    devices.finish(MediaKind.camera);
    await first;
    await pumpEventQueue();
    if (devices.pending.containsKey(MediaKind.camera)) {
      devices.finish(MediaKind.camera);
    }
    await last;

    check(devices.on).deepEquals({MediaKind.camera});
  });

  test('a lost device is not captured again by itself', () async {
    final devices = _Devices();
    final turnOn = devices.loop.turnOn(MediaKind.camera);
    await pumpEventQueue();
    devices.finish(MediaKind.camera);
    await turnOn;

    devices.on.remove(MediaKind.camera);
    devices.loop.lose(MediaKind.camera);
    await devices.loop.run();

    check(devices.starts).length.equals(1);
    check(
      devices.loop.intentOf(MediaKind.camera).problem,
    ).equals(DeviceProblem.lost);
  });

  test('an unavailable device waits, then starts when run again', () async {
    final devices = _Devices()..available = false;
    devices.loop.setIntent(MediaKind.camera, const DeviceIntent(wanted: true));
    await devices.loop.run();
    check(devices.starts).isEmpty();

    devices.available = true;
    final run = devices.loop.run();
    await pumpEventQueue();
    devices.finish(MediaKind.camera);
    await run;
    check(devices.on).deepEquals({MediaKind.camera});
  });

  test('a start that reports success but stays off is not retried', () async {
    var starts = 0;
    final loop = CaptureLoop(
      start: (_) async {
        starts++;
        return null;
      },
      stop: (_) async {},
      isOn: (_) => false,
      permissionOf: (_) => MediaPermission.granted,
      platform: () => const IosApp(),
    );

    await loop.turnOn(MediaKind.camera);

    check(starts).equals(1);
  });

  test('isStarting reports a start in flight', () async {
    final devices = _Devices();
    final turnOn = devices.loop.turnOn(MediaKind.camera);
    await pumpEventQueue();
    check(devices.loop.isStarting(MediaKind.camera)).isTrue();
    devices.finish(MediaKind.camera);
    await turnOn;
    check(devices.loop.isStarting(MediaKind.camera)).isFalse();
  });
}
