// Each step of a device's history is its own statement, to read in order.
// ignore_for_file: cascade_invocations

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/pre_join/capture.dart';

const _ios = IosApp();
const _chrome = WebPlatform(browser: WebBrowser.chrome, os: HostOs.macos);

/// One device's capture over time: the intent, whether it's capturing, and
/// the permission, stepped through events the way a capture owner would.
class _Device {
  _Device(this.platform, {this.permission = MediaPermission.unknown});

  final PlatformInfo platform;
  MediaPermission permission;
  DeviceIntent intent = const DeviceIntent();
  bool isOn = false;
  bool available = true;

  CaptureEffect get next => nextEffect(
    intent,
    isOn: isOn,
    permission: () => permission,
    platform: platform,
    available: available,
  );

  void started([CaptureFailure? failure]) {
    intent = afterStart(intent, failure);
    isOn = failure == null;
  }
}

void main() {
  test('nothing happens to a device nobody wants', () {
    final device = _Device(_ios, permission: MediaPermission.granted);
    check(device.next).equals(CaptureEffect.none);
  });

  test('X2: native waits for a grant, then starts', () {
    final device = _Device(_ios)..intent = const DeviceIntent(wanted: true);
    check(device.next).equals(CaptureEffect.none);

    device.permission = MediaPermission.granted;
    check(device.next).equals(CaptureEffect.start);
    device.started();
    check(device.next).equals(CaptureEffect.none);
  });

  test('WS2: web captures to ask, and stops asking after a dismissal', () {
    final device = _Device(_chrome)..intent = const DeviceIntent(wanted: true);
    check(device.next).equals(CaptureEffect.start);

    // WC2: dismissed; the permission is still unknown, so don't ask again.
    device.started(const PermissionRefused(MediaPermission.unknown));
    check(device.next).equals(CaptureEffect.none);
  });

  test('X12: a refusal restarts once the permission changes', () {
    final device = _Device(_chrome)..intent = const DeviceIntent(wanted: true);
    device
      ..started(const PermissionRefused(MediaPermission.blocked))
      ..permission = MediaPermission.blocked;
    check(device.next).equals(CaptureEffect.none);

    device.permission = MediaPermission.granted;
    check(device.next).equals(CaptureEffect.start);
  });

  test('X9: a device problem waits for the user, even after a grant', () {
    final device = _Device(_chrome, permission: MediaPermission.granted)
      ..intent = const DeviceIntent(wanted: true);
    device.started(const DeviceFailed(DeviceProblem.inUse));
    check(device.intent.problem).equals(DeviceProblem.inUse);
    check(device.next).equals(CaptureEffect.none);

    device.permission = MediaPermission.unknown;
    device.permission = MediaPermission.granted;
    check(device.next).equals(CaptureEffect.none);

    device.intent = wantOn(device.intent);
    check(device.next).equals(CaptureEffect.start);
    device.started();
    check(device.intent.problem).isNull();
    check(device.intent.retry).isFalse();
  });

  test('WS1/WF2: the user can always try, even against a stale refusal', () {
    final device = _Device(_chrome, permission: MediaPermission.blocked)
      ..intent = const DeviceIntent(wanted: true);
    check(device.next).equals(CaptureEffect.none);

    device.intent = wantOn(device.intent);
    check(device.next).equals(CaptureEffect.start);
    device.started(const PermissionRefused(MediaPermission.blocked));
    check(device.next).equals(CaptureEffect.none);
  });

  test('X13/W9: a lost device stays off until the user turns it on', () {
    final device = _Device(_chrome, permission: MediaPermission.granted)
      ..intent = const DeviceIntent(wanted: true);
    device.started();

    device
      ..intent = afterLoss(device.intent)
      ..isOn = false;
    check(device.intent.problem).equals(DeviceProblem.lost);
    check(device.next).equals(CaptureEffect.none);

    // Safari may answer granted afterwards; that doesn't recapture it.
    device.permission = MediaPermission.granted;
    check(device.next).equals(CaptureEffect.none);

    device.intent = wantOn(device.intent);
    check(device.next).equals(CaptureEffect.start);
  });

  test('turning a device off stops it and forgets its problems', () {
    final device = _Device(_chrome, permission: MediaPermission.granted)
      ..intent = const DeviceIntent(wanted: true);
    device.started();

    device.intent = wantOff(device.intent);
    check(device.next).equals(CaptureEffect.stop);
    device.isOn = false;
    check(device.next).equals(CaptureEffect.none);
    check(device.intent).equals(const DeviceIntent());
  });

  test('a device turned off stays off when access is granted', () {
    final device = _Device(_ios)..intent = wantOff(const DeviceIntent());
    device.permission = MediaPermission.granted;
    check(device.next).equals(CaptureEffect.none);
  });

  test('a turn-off while starting is honored when the start lands', () {
    final device = _Device(_chrome, permission: MediaPermission.granted)
      ..intent = wantOn(const DeviceIntent());
    check(device.next).equals(CaptureEffect.start);

    device
      ..intent = wantOff(device.intent)
      ..started();
    check(device.next).equals(CaptureEffect.stop);
  });

  test('W6: an unavailable device waits without failing', () {
    final device = _Device(_chrome, permission: MediaPermission.granted)
      ..intent = wantOn(const DeviceIntent())
      ..available = false;
    check(device.next).equals(CaptureEffect.none);

    device.available = true;
    check(device.next).equals(CaptureEffect.start);
  });

  test('stopping or a user retry never reads the permission', () {
    MediaPermission unread() => throw StateError('permission was read');
    check(
      nextEffect(
        const DeviceIntent(),
        isOn: true,
        permission: unread,
        platform: _ios,
      ),
    ).equals(CaptureEffect.stop);
    check(
      nextEffect(
        wantOn(const DeviceIntent()),
        isOn: false,
        permission: unread,
        platform: _ios,
      ),
    ).equals(CaptureEffect.start);
  });

  test('a start that fails after the user turned it off leaves it off', () {
    for (final failure in [
      const DeviceFailed(DeviceProblem.inUse),
      const PermissionRefused(MediaPermission.blocked),
    ]) {
      final intent = afterStart(wantOff(const DeviceIntent()), failure);
      check(intent).equals(const DeviceIntent());
    }
  });
}
