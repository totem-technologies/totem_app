import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/ui/recovery_content.dart';

const _ios = IosApp();
const _android = AndroidApp();

WebPlatform _web(
  WebBrowser browser, {
  HostOs os = HostOs.macos,
  bool touch = false,
  bool inApp = false,
}) => WebPlatform(
  browser: browser,
  os: os,
  hasTouchScreen: touch,
  inAppBrowser: inApp,
);

void main() {
  test('every access, kind and platform produces content', () {
    final platforms = <PlatformInfo>[
      _ios,
      _android,
      const OtherPlatform(),
      for (final browser in WebBrowser.values)
        for (final os in HostOs.values) _web(browser, os: os),
      _web(WebBrowser.other, os: HostOs.ios, inApp: true),
    ];
    for (final platform in platforms) {
      for (final kind in MediaKind.values) {
        for (final permission in MediaPermission.values) {
          for (final problem in [null, ...DeviceProblem.values]) {
            final content = recoveryContent(
              kind,
              permission,
              problem,
              platform,
            );
            check(content.title).isNotEmpty();
            check(content.message).isNotEmpty();
          }
        }
      }
    }
  });

  test('copy names the device it is about', () {
    final mic = recoveryContent(
      MediaKind.microphone,
      MediaPermission.blocked,
      null,
      _ios,
    );
    check(mic.title.toLowerCase()).contains('microphone');
    final camera = recoveryContent(
      MediaKind.camera,
      MediaPermission.blocked,
      null,
      _ios,
    );
    check(camera.title.toLowerCase()).contains('camera');
  });

  test('I2/A2: native blocked opens Settings', () {
    for (final platform in [_ios, _android]) {
      final content = recoveryContent(
        MediaKind.microphone,
        MediaPermission.blocked,
        null,
        platform,
      );
      check(content.action).equals(RecoveryAction.openAppSettings);
      check(content.actionLabel).equals('Open Settings');
    }
  });

  test('X3: camera copy says it is optional', () {
    final content = recoveryContent(
      MediaKind.camera,
      MediaPermission.unknown,
      null,
      _ios,
    );
    check(content.message.toLowerCase()).contains('optional');
  });

  group('browser site settings', () {
    test('Safari with a macOS user agent shows Mac and iPad steps', () {
      final content = recoveryContent(
        MediaKind.camera,
        MediaPermission.blocked,
        null,
        _web(WebBrowser.safari),
      );
      check(content.sections.map((s) => s.heading))
          .deepEquals(['On a Mac', 'On an iPad']);
    });

    test('touch only puts the iPad steps first', () {
      final content = recoveryContent(
        MediaKind.camera,
        MediaPermission.blocked,
        null,
        _web(WebBrowser.safari, touch: true),
      );
      check(content.sections.map((s) => s.heading))
          .deepEquals(['On an iPad', 'On a Mac']);
    });

    test('Safari on iPhone shows one set of steps', () {
      final content = recoveryContent(
        MediaKind.camera,
        MediaPermission.blocked,
        null,
        _web(WebBrowser.safari, os: HostOs.ios),
      );
      check(content.sections).length.equals(1);
    });

    test('WF2: Firefox says to reload', () {
      final content = recoveryContent(
        MediaKind.microphone,
        MediaPermission.blocked,
        null,
        _web(WebBrowser.firefox),
      );
      check(content.sections.single.steps.last.toLowerCase())
          .contains('reload');
    });

    test('W8: Chrome on Android mentions the Android app permission', () {
      final content = recoveryContent(
        MediaKind.microphone,
        MediaPermission.blocked,
        null,
        _web(WebBrowser.chrome, os: HostOs.android),
      );
      check(content.helper).isNotNull().contains('Android Settings');
    });

    test('web blocked offers to check again', () {
      final content = recoveryContent(
        MediaKind.microphone,
        MediaPermission.blocked,
        null,
        _web(WebBrowser.chrome),
      );
      check(content.canCheckAgain).isTrue();
    });
  });

  group('system privacy settings', () {
    test('WC3: macOS points at System Settings and names the browser', () {
      final content = recoveryContent(
        MediaKind.camera,
        MediaPermission.blockedBySystem,
        null,
        _web(WebBrowser.chrome),
      );
      final steps = content.sections.single.steps.join(' ');
      check(steps).contains('System Settings');
      check(steps).contains('Chrome');
    });

    test('Windows points at Privacy & security', () {
      final content = recoveryContent(
        MediaKind.camera,
        MediaPermission.blockedBySystem,
        null,
        _web(WebBrowser.edge, os: HostOs.windows),
      );
      check(content.sections.single.steps.join(' '))
          .contains('Privacy & security');
    });
  });

  test('an unknown iOS browser is never named as one', () {
    final platform = _web(WebBrowser.other, os: HostOs.ios);
    for (final permission in [
      MediaPermission.blocked,
      MediaPermission.blockedBySystem,
    ]) {
      final content = recoveryContent(
        MediaKind.camera,
        permission,
        null,
        platform,
      );
      final text = [
        ...content.sections.expand((section) => section.steps),
        ?content.helper,
      ].join(' ');
      check(text).not((it) => it.contains('Apps → your browser'));
      check(text).contains("the browser you're using");
    }
  });

  test('iOS browsers other than Safari reload first', () {
    final content = recoveryContent(
      MediaKind.microphone,
      MediaPermission.blocked,
      null,
      _web(WebBrowser.chrome, os: HostOs.ios),
    );
    check(content.sections.single.steps.first).equals('Reload the page.');
    // iOS lists apps under Apps only from iOS 18, so no path is given.
    check(content.helper).isNotNull()
      ..contains('find Chrome')
      ..not((it) => it.contains('Apps'));
  });

  test('W8: an unknown Android browser also points at Android settings', () {
    final content = recoveryContent(
      MediaKind.camera,
      MediaPermission.blocked,
      null,
      _web(WebBrowser.other, os: HostOs.android),
    );
    check(content.helper).isNotNull().contains("the browser you're using");
  });

  test('W8: Firefox on Android also points at Android settings', () {
    final content = recoveryContent(
      MediaKind.microphone,
      MediaPermission.blocked,
      null,
      _web(WebBrowser.firefox, os: HostOs.android),
    );
    check(content.sections.single.steps.first).startsWith('Tap');
    check(content.helper).isNotNull().contains('Apps → Firefox');
  });

  test('X9: in use and not found read differently', () {
    final inUse = recoveryContent(
      MediaKind.camera,
      MediaPermission.granted,
      DeviceProblem.inUse,
      _android,
    );
    final notFound = recoveryContent(
      MediaKind.camera,
      MediaPermission.granted,
      DeviceProblem.notFound,
      _android,
    );
    check(inUse.title).not((it) => it.equals(notFound.title));
    check(inUse.actionLabel).equals('Try again');
  });

  test('WS5: in-app browser suggests the system browser', () {
    final content = recoveryContent(
      MediaKind.microphone,
      MediaPermission.unsupported,
      null,
      _web(WebBrowser.other, os: HostOs.ios, inApp: true),
    );
    check(content.action).equals(RecoveryAction.openInBrowser);
    check(content.message).contains('Safari');
  });
}
