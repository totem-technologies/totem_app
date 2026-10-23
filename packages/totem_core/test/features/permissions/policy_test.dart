import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/policy.dart';

const ios = IosApp();
const android = AndroidApp();
const chrome = WebPlatform(browser: WebBrowser.chrome, os: HostOs.macos);

const _micGranted = MediaPermissions(microphone: MediaPermission.granted);

void main() {
  group('joinReadiness', () {
    test('X1: checking until permissions have been queried', () {
      check(
        joinReadiness(
          permissions: null,
          microphoneProblem: null,
          mediaSettled: true,
        ),
      ).equals(JoinReadiness.checking);
    });

    test('checking until the preview has settled', () {
      check(
        joinReadiness(
          permissions: _micGranted,
          microphoneProblem: null,
          mediaSettled: false,
        ),
      ).equals(JoinReadiness.checking);
    });

    test('X1: ready once the microphone is granted', () {
      check(
        joinReadiness(
          permissions: _micGranted,
          microphoneProblem: null,
          mediaSettled: true,
        ),
      ).equals(JoinReadiness.ready);
    });

    test('X3: camera never blocks joining', () {
      for (final camera in MediaPermission.values) {
        check(
          joinReadiness(
            permissions: MediaPermissions(
              camera: camera,
              microphone: MediaPermission.granted,
            ),
            microphoneProblem: null,
            mediaSettled: true,
          ),
        ).equals(JoinReadiness.ready);
      }
    });

    test('X4: microphone needed for any permission but granted', () {
      for (final microphone in MediaPermission.values) {
        if (microphone == MediaPermission.granted) continue;
        check(
          joinReadiness(
            permissions: MediaPermissions(microphone: microphone),
            microphoneProblem: null,
            mediaSettled: true,
          ),
        ).equals(JoinReadiness.microphoneNeeded);
      }
    });

    test('X4/W9: microphone needed while the granted mic has a problem', () {
      for (final problem in DeviceProblem.values) {
        check(
          joinReadiness(
            permissions: _micGranted,
            microphoneProblem: problem,
            mediaSettled: true,
          ),
        ).equals(JoinReadiness.microphoneNeeded);
      }
    });
  });

  group('recoveryFor', () {
    test('granted with no problem needs nothing', () {
      check(
        recoveryFor(MediaPermission.granted, null, ios),
      ).equals(RecoveryAction.none);
    });

    test('X11/A1: unknown and denied can be asked again', () {
      for (final platform in [ios, android, chrome]) {
        check(
          recoveryFor(MediaPermission.unknown, null, platform),
        ).equals(RecoveryAction.request);
        check(
          recoveryFor(MediaPermission.denied, null, platform),
        ).equals(RecoveryAction.request);
      }
    });

    test('I2/A2: blocked on native opens app Settings', () {
      check(
        recoveryFor(MediaPermission.blocked, null, ios),
      ).equals(RecoveryAction.openAppSettings);
      check(
        recoveryFor(MediaPermission.blocked, null, android),
      ).equals(RecoveryAction.openAppSettings);
    });

    test('W3/WF2: blocked on web shows browser site settings', () {
      check(
        recoveryFor(MediaPermission.blocked, null, chrome),
      ).equals(RecoveryAction.showBrowserSiteSettings);
    });

    test('WC3/WF4: blocked by the OS shows system privacy settings', () {
      check(
        recoveryFor(MediaPermission.blockedBySystem, null, chrome),
      ).equals(RecoveryAction.showSystemPrivacySettings);
    });

    test('browser and OS settings steps are only offered on web', () {
      for (final permission in MediaPermission.values) {
        for (final problem in [null, ...DeviceProblem.values]) {
          for (final platform in [ios, android, const OtherPlatform()]) {
            check([
              RecoveryAction.showBrowserSiteSettings,
              RecoveryAction.showSystemPrivacySettings,
            ]).not(
              (it) => it.contains(recoveryFor(permission, problem, platform)),
            );
          }
        }
      }
    });

    test('I3: restricted is explained, not fixable here', () {
      check(
        recoveryFor(MediaPermission.restricted, null, ios),
      ).equals(RecoveryAction.explainRestricted);
    });

    test('X9/X10: a device problem with the permission fine is retried', () {
      for (final problem in DeviceProblem.values) {
        check(
          recoveryFor(MediaPermission.granted, problem, chrome),
        ).equals(RecoveryAction.retry);
      }
    });

    test('a device problem beats an unknown permission on web', () {
      check(
        recoveryFor(MediaPermission.unknown, DeviceProblem.inUse, chrome),
      ).equals(RecoveryAction.retry);
    });

    test('X13: a refusal beats a device problem', () {
      check(
        recoveryFor(MediaPermission.blocked, DeviceProblem.lost, chrome),
      ).equals(RecoveryAction.showBrowserSiteSettings);
      check(
        recoveryFor(MediaPermission.denied, DeviceProblem.lost, android),
      ).equals(RecoveryAction.request);
    });

    test('WS5: unsupported in an in-app browser suggests a real browser', () {
      const inApp = WebPlatform(
        browser: WebBrowser.other,
        os: HostOs.ios,
        inAppBrowser: true,
      );
      check(
        recoveryFor(MediaPermission.unsupported, null, inApp),
      ).equals(RecoveryAction.openInBrowser);
    });

    test('W1: unsupported elsewhere is explained', () {
      check(
        recoveryFor(MediaPermission.unsupported, null, chrome),
      ).equals(RecoveryAction.explainUnsupported);
    });
  });

  group('needsAttention', () {
    test('X7: flags devices the user must fix outside the prompt', () {
      check(needsAttention(MediaPermission.blocked, null, ios)).isTrue();
      check(
        needsAttention(MediaPermission.granted, DeviceProblem.inUse, chrome),
      ).isTrue();
      check(
        needsAttention(MediaPermission.granted, DeviceProblem.lost, android),
      ).isTrue();
    });

    test('not for granted, promptable or not-yet-known states', () {
      check(needsAttention(null, null, ios)).isFalse();
      check(needsAttention(MediaPermission.granted, null, ios)).isFalse();
      check(needsAttention(MediaPermission.unknown, null, ios)).isFalse();
      check(needsAttention(MediaPermission.denied, null, android)).isFalse();
    });
  });

  group('capturesAllowed', () {
    test('X2: native waits for a grant, so only the user prompts', () {
      for (final platform in [ios, android]) {
        for (final permission in MediaPermission.values) {
          check(
            capturesAllowed(permission, platform),
          ).equals(permission == MediaPermission.granted);
        }
      }
    });

    test('WS2: web captures to ask, unless capture is known to fail', () {
      const failing = {
        MediaPermission.blocked,
        MediaPermission.blockedBySystem,
        MediaPermission.restricted,
        MediaPermission.unsupported,
      };
      for (final permission in MediaPermission.values) {
        check(
          capturesAllowed(permission, chrome),
        ).equals(!failing.contains(permission));
      }
    });
  });

  test('A2: only Android explains a refusal from its prompt', () {
    check(explainsRefusal(MediaPermission.blocked, android)).isTrue();
    check(explainsRefusal(MediaPermission.denied, android)).isFalse();
    for (final platform in [ios, chrome]) {
      check(explainsRefusal(MediaPermission.blocked, platform)).isFalse();
    }
  });

  group('userCaptureStep', () {
    test('X6: native asks before capturing when it may ask', () {
      for (final platform in [ios, android]) {
        check(
          userCaptureStep(MediaPermission.granted, platform),
        ).equals(UserCaptureStep.capture);
        check(
          userCaptureStep(MediaPermission.unknown, platform),
        ).equals(UserCaptureStep.requestFirst);
        check(
          userCaptureStep(MediaPermission.denied, platform),
        ).equals(UserCaptureStep.requestFirst);
      }
    });

    test('X7: native shows recovery when it can no longer ask', () {
      for (final permission in [
        MediaPermission.blocked,
        MediaPermission.restricted,
        MediaPermission.unsupported,
      ]) {
        check(userCaptureStep(permission, ios)).equals(UserCaptureStep.recover);
      }
      for (final permission in [
        MediaPermission.restricted,
        MediaPermission.unsupported,
      ]) {
        check(
          userCaptureStep(permission, android),
        ).equals(UserCaptureStep.recover);
      }
    });

    test('A2: Android asks again after a refusal it remembers', () {
      check(
        userCaptureStep(MediaPermission.blocked, android),
      ).equals(UserCaptureStep.requestFirst);
    });

    test('WS1/WF2: web always tries, since queries may be stale', () {
      for (final permission in MediaPermission.values) {
        check(
          userCaptureStep(permission, chrome),
        ).equals(UserCaptureStep.capture);
      }
    });
  });

  group('reconcileQuery', () {
    test('first query fills in what nothing else has learned', () {
      check(
        reconcileQuery(
          current: MediaPermission.unknown,
          previousQuery: null,
          query: MediaPermission.granted,
        ),
      ).equals(MediaPermission.granted);
    });

    test('first query does not override a learned permission', () {
      check(
        reconcileQuery(
          current: MediaPermission.blocked,
          previousQuery: null,
          query: MediaPermission.granted,
        ),
      ).equals(MediaPermission.blocked);
    });

    test('A2: unchanged Android status keeps a remembered refusal', () {
      check(
        reconcileQuery(
          current: MediaPermission.blocked,
          previousQuery: MediaPermission.unknown,
          query: MediaPermission.unknown,
        ),
      ).equals(MediaPermission.blocked);
    });

    test('WS1/WF3/A5: an unchanged query never overrides capture', () {
      check(
        reconcileQuery(
          current: MediaPermission.blockedBySystem,
          previousQuery: MediaPermission.granted,
          query: MediaPermission.granted,
        ),
      ).equals(MediaPermission.blockedBySystem);
    });

    test('X5: granted in Settings overrides a refusal', () {
      check(
        reconcileQuery(
          current: MediaPermission.blocked,
          previousQuery: MediaPermission.unknown,
          query: MediaPermission.granted,
        ),
      ).equals(MediaPermission.granted);
    });

    test('WC1: an expired one-time grant becomes unknown', () {
      check(
        reconcileQuery(
          current: MediaPermission.granted,
          previousQuery: MediaPermission.granted,
          query: MediaPermission.unknown,
        ),
      ).equals(MediaPermission.unknown);
    });
  });
}
