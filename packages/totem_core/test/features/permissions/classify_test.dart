import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:totem_core/features/permissions/classify.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

const ios = IosApp();
const android = AndroidApp();

WebPlatform web(WebBrowser browser, {HostOs os = HostOs.macos}) =>
    WebPlatform(browser: browser, os: os);

void main() {
  group('permissionFromStatus', () {
    test('granted, limited and provisional are granted', () {
      for (final status in [
        PermissionStatus.granted,
        PermissionStatus.limited,
        PermissionStatus.provisional,
      ]) {
        check(permissionFromStatus(status)).equals(MediaPermission.granted);
      }
    });

    test('I1: iOS reports never-asked as denied, which is unknown', () {
      check(
        permissionFromStatus(PermissionStatus.denied),
      ).equals(MediaPermission.unknown);
    });

    test(
      'I2: iOS reports a refusal as permanentlyDenied, which is blocked',
      () {
        check(
          permissionFromStatus(PermissionStatus.permanentlyDenied),
        ).equals(MediaPermission.blocked);
      },
    );

    test('I3: restricted by Screen Time or MDM', () {
      check(
        permissionFromStatus(PermissionStatus.restricted),
      ).equals(MediaPermission.restricted);
    });

    test('A2: Android status says denied even after two refusals', () {
      // Only request results carry the refusal; the status is a hint that
      // reconcileQuery keeps from overriding it.
      check(
        permissionFromStatus(PermissionStatus.denied),
      ).equals(MediaPermission.unknown);
    });
  });

  group('permissionFromRequestResult', () {
    test('A1/A3: Android refusal or dismissal can be asked again', () {
      check(
        permissionFromRequestResult(PermissionStatus.denied, android),
      ).equals(MediaPermission.denied);
    });

    test('A2: Android second refusal is blocked', () {
      check(
        permissionFromRequestResult(
          PermissionStatus.permanentlyDenied,
          android,
        ),
      ).equals(MediaPermission.blocked);
    });

    test('I2: iOS refusal is blocked', () {
      check(
        permissionFromRequestResult(PermissionStatus.permanentlyDenied, ios),
      ).equals(MediaPermission.blocked);
    });

    test('I1: iOS request that shows no prompt stays unknown', () {
      check(
        permissionFromRequestResult(PermissionStatus.denied, ios),
      ).equals(MediaPermission.unknown);
    });

    test('granted', () {
      check(
        permissionFromRequestResult(PermissionStatus.granted, android),
      ).equals(MediaPermission.granted);
    });
  });

  group('permissionFromWebState', () {
    test('W4: granted, prompt, denied', () {
      check(permissionFromWebState('granted')).equals(MediaPermission.granted);
      check(permissionFromWebState('prompt')).equals(MediaPermission.unknown);
      check(permissionFromWebState('denied')).equals(MediaPermission.blocked);
    });

    test('W4: unrecognized states are unknown', () {
      check(permissionFromWebState('weird')).equals(MediaPermission.unknown);
    });
  });

  group('captureErrorName', () {
    test('finds the DOMException name anywhere in the message', () {
      check(
        captureErrorName('TrackCreateException: NotAllowedError: denied'),
      ).equals('NotAllowedError');
      check(
        captureErrorName(
          PlatformException(
            code: 'getUserMedia',
            message: 'getUserMedia(): DOMException, NotAllowedError',
          ),
        ),
      ).equals('NotAllowedError');
      check(
        captureErrorName('Unable to getUserMedia: NotFoundError'),
      ).equals('NotFoundError');
    });

    test('maps legacy Chrome names to the standard ones', () {
      check(
        captureErrorName('PermissionDeniedError'),
      ).equals('NotAllowedError');
      check(captureErrorName('DevicesNotFoundError')).equals('NotFoundError');
      check(captureErrorName('TrackStartError')).equals('NotReadableError');
      check(
        captureErrorName('ConstraintNotSatisfiedError'),
      ).equals('OverconstrainedError');
    });

    test('returns null for unrelated errors', () {
      check(captureErrorName(StateError('boom'))).isNull();
    });
  });

  group('classifyCaptureError, native', () {
    test('I2: iOS NotAllowedError is blocked', () {
      check(
        classifyCaptureError('Unable to getUserMedia: NotAllowedError', ios),
      ).equals(const PermissionRefused(MediaPermission.blocked));
    });

    test('A1: Android NotAllowedError can be asked again', () {
      check(
        classifyCaptureError(
          'getUserMedia(): DOMException, NotAllowedError',
          android,
        ),
      ).equals(const PermissionRefused(MediaPermission.denied));
    });

    test('X10: NotFoundError is notFound', () {
      check(
        classifyCaptureError('NotFoundError', ios),
      ).equals(const DeviceFailed(DeviceProblem.notFound));
    });

    test('unrecognized errors are unclassified', () {
      check(classifyCaptureError(StateError('boom'), ios)).isNull();
    });

    test('X10: a native capture with no device is notFound', () {
      for (final platform in [ios, android]) {
        check(
          classifyCaptureError(
            'LiveKit Exception: [TrackCreateException] Failed to create '
            'stream, at least 1 video or audio track should exist',
            platform,
          ),
        ).equals(const DeviceFailed(DeviceProblem.notFound));
      }
    });

    test('I7: a mic asked for while in the background is a device failure', () {
      check(
        classifyCaptureError(
          'TrackCreateException: Microphone permission could not be '
          'requested because the app is not in the foreground',
          ios,
        ),
      ).equals(const DeviceFailed(DeviceProblem.failed));
    });

    test("I2: iOS's audio session refusing the microphone is blocked", () {
      for (final message in [
        'TrackCreateException: Microphone permission is not granted',
        'TrackCreateException: Microphone permission was denied.',
      ]) {
        check(
          classifyCaptureError(message, ios),
        ).equals(const PermissionRefused(MediaPermission.blocked));
      }
    });
  });

  group('classifyCaptureError, web', () {
    final chrome = web(WebBrowser.chrome);
    final firefox = web(WebBrowser.firefox);
    final safari = web(WebBrowser.safari);

    test('every iOS browser reports errors like Safari', () {
      for (final browser in WebBrowser.values) {
        final platform = web(browser, os: HostOs.ios);
        check(
          classifyCaptureError('NotReadableError', platform),
        ).equals(const DeviceFailed(DeviceProblem.inUse));
        check(
          classifyCaptureError('NotFoundError', platform, deviceListed: true),
        ).equals(const DeviceFailed(DeviceProblem.notFound));
      }
    });

    test('W3: site blocked in every browser', () {
      for (final platform in [chrome, firefox, safari, web(WebBrowser.edge)]) {
        check(
          classifyCaptureError('NotAllowedError: Permission denied', platform),
        ).equals(const PermissionRefused(MediaPermission.blocked));
      }
    });

    test('WC2: Chrome prompt dismissed is unknown', () {
      check(
        classifyCaptureError('NotAllowedError: Permission dismissed', chrome),
      ).equals(const PermissionRefused(MediaPermission.unknown));
      check(
        classifyCaptureError('PermissionDismissedError', chrome),
      ).equals(const PermissionRefused(MediaPermission.unknown));
    });

    test('WC3: Chrome on macOS blocked by the OS', () {
      check(
        classifyCaptureError(
          'NotAllowedError: Permission denied by system',
          chrome,
        ),
      ).equals(const PermissionRefused(MediaPermission.blockedBySystem));
    });

    test('WC4: Chrome NotReadableError is inUse', () {
      check(
        classifyCaptureError(
          'NotReadableError: Could not start video source',
          web(WebBrowser.chrome, os: HostOs.windows),
        ),
      ).equals(const DeviceFailed(DeviceProblem.inUse));
    });

    test('WF4: Firefox NotFoundError with a listed device is an OS block', () {
      check(
        classifyCaptureError('NotFoundError', firefox, deviceListed: true),
      ).equals(const PermissionRefused(MediaPermission.blockedBySystem));
      check(
        classifyCaptureError('NotFoundError', firefox),
      ).equals(const DeviceFailed(DeviceProblem.notFound));
    });

    test('WF4: Chrome NotFoundError is notFound even with a listed device', () {
      check(
        classifyCaptureError('NotFoundError', chrome, deviceListed: true),
      ).equals(const DeviceFailed(DeviceProblem.notFound));
    });

    test('WF4: Firefox NotReadableError is an OS block', () {
      check(
        classifyCaptureError(
          'NotReadableError: Failed to allocate videosource',
          firefox,
        ),
      ).equals(const PermissionRefused(MediaPermission.blockedBySystem));
    });

    test('WF5: Firefox AbortError is inUse', () {
      check(
        classifyCaptureError('AbortError: Starting videoinput failed', firefox),
      ).equals(const DeviceFailed(DeviceProblem.inUse));
    });

    test('OverconstrainedError means the chosen device is gone', () {
      check(
        classifyCaptureError('OverconstrainedError', chrome),
      ).equals(const DeviceFailed(DeviceProblem.notFound));
    });

    test('W1: SecurityError and missing mediaDevices are unsupported', () {
      check(
        classifyCaptureError('SecurityError', chrome),
      ).equals(const PermissionRefused(MediaPermission.unsupported));
      check(
        classifyCaptureError(
          "TypeError: Cannot read properties of undefined (reading 'getUserMedia')",
          chrome,
        ),
      ).equals(const PermissionRefused(MediaPermission.unsupported));
    });

    test('WS5: NotAllowedError in an in-app browser is unsupported', () {
      const inApp = WebPlatform(
        browser: WebBrowser.other,
        os: HostOs.ios,
        inAppBrowser: true,
      );
      check(
        classifyCaptureError('NotAllowedError', inApp),
      ).equals(const PermissionRefused(MediaPermission.unsupported));
    });

    test('unrecognized errors are unclassified', () {
      check(classifyCaptureError('TypeError: oops', chrome)).isNull();
    });
  });
}
