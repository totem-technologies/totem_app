/// What to tell the user about a device's permission and problem, per
/// platform.
///
/// Pure: every piece of permission help copy is chosen here, so it can be
/// reviewed in one place. Widgets only render a [RecoveryContent]. IDs in
/// comments refer to `specs/permissions.md`.
library;

import 'package:flutter/foundation.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/policy.dart';

@immutable
class RecoverySection {
  const RecoverySection(this.steps, {this.heading});

  final String? heading;
  final List<String> steps;
}

@immutable
class RecoveryContent {
  const RecoveryContent({
    required this.action,
    required this.title,
    required this.message,
    this.sections = const [],
    this.helper,
    this.actionLabel,
    this.canCheckAgain = false,
  });

  final RecoveryAction action;
  final String title;
  final String message;
  final List<RecoverySection> sections;
  final String? helper;

  /// The primary button, or null when the user can only read.
  final String? actionLabel;

  /// Whether to offer capturing again after following the steps.
  final bool canCheckAgain;
}

RecoveryContent recoveryContent(
  MediaKind kind,
  MediaPermission permission,
  DeviceProblem? problem,
  PlatformInfo platform,
) {
  final device = _Device(kind);
  final action = recoveryFor(permission, problem, platform);
  return switch (action) {
    RecoveryAction.none => RecoveryContent(
      action: action,
      title: '${device.title} is on',
      message: 'Your ${device.name} is ready.',
    ),
    RecoveryAction.request => RecoveryContent(
      action: action,
      title: 'Allow your ${device.name}',
      message: device.why,
      actionLabel: 'Allow ${device.name}',
    ),
    RecoveryAction.openAppSettings => RecoveryContent(
      action: action,
      title: '${device.title} is off for Totem',
      message: 'Turn on ${device.title} for Totem in Settings, then come back.',
      sections: [_appSettingsSteps(device, platform)],
      actionLabel: 'Open Settings',
    ),
    RecoveryAction.showBrowserSiteSettings => _browserSiteSettings(
      device,
      _onWeb(platform),
    ),
    RecoveryAction.showSystemPrivacySettings => _systemPrivacySettings(
      device,
      _onWeb(platform),
    ),
    RecoveryAction.explainRestricted => RecoveryContent(
      action: action,
      title: '${device.title} is restricted',
      message:
          'Screen Time or your organization limits ${device.name} access on '
          'this device. Ask whoever manages it to allow ${device.name} '
          'access for Totem.',
    ),
    // `recoveryFor` only retries a device that has a problem.
    RecoveryAction.retry => switch (problem ?? DeviceProblem.failed) {
      DeviceProblem.inUse => RecoveryContent(
        action: action,
        title: 'Your ${device.name} is busy',
        message:
            'Another app or browser tab is using your ${device.name}. Close '
            'it first.',
        // Chrome and Edge report a Windows privacy block the same way (WC4).
        helper: _isWindows(platform)
            ? 'Still busy? Check Windows Settings → Privacy & security → '
                  '${device.title}.'
            : null,
        actionLabel: 'Try again',
      ),
      DeviceProblem.failed => RecoveryContent(
        action: action,
        title: "Your ${device.name} didn't start",
        message: 'Something went wrong starting your ${device.name}.',
        actionLabel: 'Try again',
      ),
      DeviceProblem.lost => RecoveryContent(
        action: action,
        title: 'Your ${device.name} stopped',
        message: "It stopped working. Check that it's connected.",
        actionLabel: 'Try again',
      ),
      DeviceProblem.notFound => RecoveryContent(
        action: action,
        title: 'No ${device.name} found',
        message: 'Connect a ${device.name}.',
        actionLabel: 'Try again',
      ),
    },
    RecoveryAction.openInBrowser => RecoveryContent(
      action: action,
      title: 'Open Totem in your browser',
      message:
          "This app's built-in browser can't use your ${device.name}. Open "
          'this page in ${_systemBrowser(platform)} instead.',
      actionLabel: 'Copy link',
    ),
    RecoveryAction.explainUnsupported => RecoveryContent(
      action: action,
      title: "${device.title} isn't available here",
      message: switch (platform) {
        WebPlatform() =>
          'This page needs a secure (https) connection to use your '
              '${device.name}.',
        _ => "This device doesn't support ${device.name} access in Totem.",
      },
    ),
  };
}

/// Why Totem wants [kind], in the user's words.
String mediaPurpose(MediaKind kind) => _Device(kind).why;

/// What to say in the session when a device the user relies on isn't
/// working: it stopped mid-call, such as when its permission was revoked
/// (X13), or it didn't come on, such as when the totem arrived. Tapping the
/// notice runs the device's recovery.
({String title, String message}) deviceNotice(
  MediaKind kind,
  DeviceProblem? problem,
) {
  final device = _Device(kind);
  return (
    title: problem == DeviceProblem.lost
        ? 'Your ${device.name} stopped'
        : "Your ${device.name} isn't on",
    message: switch (kind) {
      MediaKind.microphone => "Others can't hear you. Tap to fix it.",
      MediaKind.camera => "Others can't see you. Tap to fix it.",
    },
  );
}

class _Device {
  const _Device(this.kind);

  final MediaKind kind;

  String get name => switch (kind) {
    MediaKind.camera => 'camera',
    MediaKind.microphone => 'microphone',
  };

  String get title => switch (kind) {
    MediaKind.camera => 'Camera',
    MediaKind.microphone => 'Microphone',
  };

  /// The policy, in the user's words (X3, X4).
  String get why => switch (kind) {
    MediaKind.camera =>
      "Turn on your camera so others can see you. It's optional, and you can "
          'turn it off any time.',
    MediaKind.microphone =>
      "Totem needs your microphone so others can hear you when it's your "
          'turn.',
  };
}

RecoverySection _appSettingsSteps(_Device device, PlatformInfo platform) =>
    switch (platform) {
      AndroidApp() => RecoverySection([
        'Tap Open Settings.',
        'Tap Permissions, then ${device.title}.',
        'Choose Allow.',
      ]),
      _ => RecoverySection(['Tap Open Settings.', 'Turn on ${device.title}.']),
    };

/// `recoveryFor` only returns browser and OS settings steps on web.
WebPlatform _onWeb(PlatformInfo platform) => platform as WebPlatform;

RecoveryContent _browserSiteSettings(_Device device, WebPlatform platform) {
  const action = RecoveryAction.showBrowserSiteSettings;
  final title = 'Your browser is blocking the ${device.name}';
  const reload = 'Reload the page.';
  final allow = 'Set ${device.title} to Allow.';
  final (sections, helper) = switch ((platform.browser, platform.os)) {
    // Every iOS browser is WebKit, but only Safari has per-site settings
    // in the page menu.
    (WebBrowser.safari, HostOs.ios) => ([_iosSafariSteps(allow, reload)], null),
    // Their refusal lasts until the page reloads (WS1).
    (_, HostOs.ios) => (
      [
        const RecoverySection([reload, 'Choose Allow when asked.']),
      ],
      'Still blocked? Open the Settings app, find '
          '${_appName(platform)}, turn on ${device.title}, and come back.',
    ),
    // iPadOS Safari reports macOS, so both are shown, iPad first on a
    // touchscreen.
    (WebBrowser.safari, _) => (
      platform.hasTouchScreen
          ? [
              _iosSafariSteps(allow, reload, heading: 'On an iPad'),
              _macSafariSteps(allow, reload),
            ]
          : [
              _macSafariSteps(allow, reload),
              _iosSafariSteps(allow, reload, heading: 'On an iPad'),
            ],
      null,
    ),
    (WebBrowser.firefox, HostOs.android) => (
      [
        RecoverySection([
          'Tap the icon to the left of the address bar.',
          'Turn on ${device.title}, or clear its Blocked setting.',
          'Reload the page and choose Allow.',
        ]),
      ],
      // The site can be allowed while Android blocks the browser (W8).
      'Still blocked? Open Android Settings → ${_appsEntry(platform)} → '
          'Permissions and allow ${device.title}.',
    ),
    (WebBrowser.firefox, _) => (
      [
        RecoverySection([
          'Click the crossed-out ${device.name} icon in the address bar.',
          'Clear the Blocked setting.',
          'Reload the page and choose Allow.',
        ]),
      ],
      'Firefox forgets temporary blocks on reload, so a refresh is often '
          'all it takes.',
    ),
    // Chrome and Edge report the change to the page, so Check again works
    // without a reload.
    (WebBrowser.chrome || WebBrowser.edge, HostOs.android) => (
      [
        RecoverySection([
          'Tap the icon to the left of the address bar.',
          'Tap Permissions, then turn on ${device.title}.',
        ]),
      ],
      // The site can be allowed while Android blocks the browser (W8).
      'Still blocked? Open Android Settings → Apps → '
          '${_browserName(platform)} → Permissions and allow '
          '${device.title}.',
    ),
    (WebBrowser.chrome || WebBrowser.edge, _) => (
      [
        RecoverySection([
          'Click the icon to the left of the address bar.',
          'Turn on ${device.title}, or set it to Allow.',
        ]),
      ],
      null,
    ),
    (WebBrowser.other, _) => (
      [
        RecoverySection([
          "Open your browser's settings for this site.",
          'Allow ${device.title}.',
          reload,
        ]),
      ],
      // The site can be allowed while Android blocks the browser (W8).
      platform.os == HostOs.android
          ? 'Still blocked? Open Android Settings → ${_appsEntry(platform)} '
                '→ Permissions and allow ${device.title}.'
          : null,
    ),
  };
  return RecoveryContent(
    action: action,
    title: title,
    message: 'Change this in ${_browserName(platform)}:',
    sections: sections,
    helper: helper,
    canCheckAgain: true,
  );
}

RecoverySection _macSafariSteps(String allow, String reload) => RecoverySection(
  heading: 'On a Mac',
  ['Choose Safari → Settings for This Website.', allow, reload],
);

RecoverySection _iosSafariSteps(
  String allow,
  String reload, {
  String? heading,
}) => RecoverySection(heading: heading, [
  'Tap the page menu button in the address bar, then Website Settings.',
  allow,
  reload,
]);

RecoveryContent _systemPrivacySettings(_Device device, WebPlatform platform) {
  final browser = _browserName(platform);
  final steps = switch (platform.os) {
    HostOs.macos => [
      'Open System Settings → Privacy & Security → ${device.title}.',
      'Turn on $browser.',
      'Quit and reopen $browser if it asks.',
    ],
    HostOs.windows => [
      'Open Settings → Privacy & security → ${device.title}.',
      'Turn on ${device.title} access and let desktop apps use it.',
      'Reload the page.',
    ],
    HostOs.android => [
      'Open Android Settings → ${_appsEntry(platform)} → Permissions.',
      'Allow ${device.title}.',
      'Reload the page.',
    ],
    HostOs.ios => [
      'Open the Settings app and find ${_appName(platform)}.',
      'Turn on ${device.title}.',
      'Reload the page.',
    ],
    HostOs.linux || HostOs.other => [
      "Check your device's privacy settings and allow $browser to use the ${device.name}.",
      'Reload the page.',
    ],
  };
  return RecoveryContent(
    action: RecoveryAction.showSystemPrivacySettings,
    title: 'Your device is blocking the ${device.name}',
    message: '$browser is allowed, but your device settings block it.',
    sections: [RecoverySection(steps)],
    canCheckAgain: true,
  );
}

bool _isWindows(PlatformInfo platform) =>
    platform is WebPlatform && platform.os == HostOs.windows;

String _browserName(PlatformInfo platform) => switch (platform) {
  WebPlatform(browser: WebBrowser.chrome) => 'Chrome',
  WebPlatform(browser: WebBrowser.edge) => 'Edge',
  WebPlatform(browser: WebBrowser.firefox) => 'Firefox',
  WebPlatform(browser: WebBrowser.safari) => 'Safari',
  _ => 'your browser',
};

/// The browser's entry in Android's list of apps, named when it's known.
String _appsEntry(PlatformInfo platform) => 'Apps → ${_appName(platform)}';

/// The browser as an app to look for in the OS settings. iOS lists apps on
/// the Settings home screen, or under Apps from iOS 18, so iOS steps say
/// "find" it rather than give a path.
String _appName(PlatformInfo platform) => switch (platform) {
  WebPlatform(browser: WebBrowser.other) => "the browser you're using",
  _ => _browserName(platform),
};

String _systemBrowser(PlatformInfo platform) => switch (platform) {
  WebPlatform(os: HostOs.ios) || WebPlatform(os: HostOs.macos) => 'Safari',
  WebPlatform(os: HostOs.android) => 'Chrome',
  _ => 'your browser',
};
