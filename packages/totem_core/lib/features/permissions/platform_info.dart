/// Where the app is running, as far as permissions are concerned.
///
/// This is the single place platform differences branch from. Code that
/// behaves differently per platform switches over [PlatformInfo]
/// exhaustively, so adding a platform or browser is a compile error at every
/// decision that needs to handle it.
library;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/permissions/platform_info_stub.dart'
    if (dart.library.js_interop) 'package:totem_core/features/permissions/platform_info_web.dart';

part 'platform_info.g.dart';

/// The platform this build is running on.
@Riverpod(keepAlive: true)
PlatformInfo platformInfo(Ref ref) => currentPlatformInfo();

PlatformInfo currentPlatformInfo() {
  if (kIsWeb || kIsWasm) {
    return WebPlatform.fromUserAgent(
      webUserAgent,
      maxTouchPoints: webMaxTouchPoints,
    );
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => const IosApp(),
    TargetPlatform.android => const AndroidApp(),
    _ => const OtherPlatform(),
  };
}

/// The browser brand, which decides recovery steps and error meanings.
///
/// On iOS every browser is WebKit, whatever brand it reports.
enum WebBrowser { chrome, edge, firefox, safari, other }

/// The operating system a browser reports in its user agent.
///
/// iPadOS Safari reports [macos] by default, and nothing in the user agent can
/// tell it apart from a Mac. See [WebPlatform.hasTouchScreen].
enum HostOs { ios, android, macos, windows, linux, other }

/// Tokens that in-app browsers add to their user agent (WS5).
const _inAppBrowserTokens = [
  'FBAN',
  'FBAV',
  'FB_IAB',
  'Instagram',
  'Line/',
  'musical_ly',
  'BytedanceWebview',
  'TikTok',
  'Snapchat',
  'LinkedInApp',
  'GSA/',
  'Twitter',
  'Pinterest',
  '; wv)',
];

@immutable
sealed class PlatformInfo {
  const PlatformInfo();
}

/// The native iOS or iPadOS app.
final class IosApp extends PlatformInfo {
  const IosApp();
}

/// The native Android app.
final class AndroidApp extends PlatformInfo {
  const AndroidApp();
}

/// The web app, in some browser.
final class WebPlatform extends PlatformInfo {
  const WebPlatform({
    required this.browser,
    required this.os,
    this.inAppBrowser = false,
    this.hasTouchScreen = false,
  });

  /// Parses a browser's user agent. [maxTouchPoints] is
  /// `navigator.maxTouchPoints`.
  factory WebPlatform.fromUserAgent(
    String userAgent, {
    int maxTouchPoints = 0,
  }) {
    final os = _osFromUserAgent(userAgent);
    return WebPlatform(
      browser: _browserFromUserAgent(userAgent),
      os: os,
      inAppBrowser:
          _inAppBrowserTokens.any(userAgent.contains) ||
          // Real iOS browsers all carry a Safari token; bare WKWebViews don't.
          (os == HostOs.ios && !userAgent.contains('Safari/')),
      hasTouchScreen: maxTouchPoints > 0,
    );
  }

  final WebBrowser browser;
  final HostOs os;

  /// A web view inside another app, where capture may be silently denied.
  final bool inAppBrowser;

  /// Whether the device reports touch input.
  ///
  /// Only a hint for ordering help text: an iPad reporting [HostOs.macos]
  /// has a touchscreen, but a future touchscreen Mac would too. Never base a
  /// permission decision on it.
  final bool hasTouchScreen;

  static HostOs _osFromUserAgent(String userAgent) {
    if (userAgent.contains('iPhone') ||
        userAgent.contains('iPad') ||
        userAgent.contains('iPod')) {
      return HostOs.ios;
    }
    // Android user agents also contain "Linux", so this comes first.
    if (userAgent.contains('Android')) return HostOs.android;
    if (userAgent.contains('Windows')) return HostOs.windows;
    if (userAgent.contains('Macintosh') || userAgent.contains('Mac OS X')) {
      return HostOs.macos;
    }
    if (userAgent.contains('Linux') || userAgent.contains('CrOS')) {
      return HostOs.linux;
    }
    return HostOs.other;
  }

  static WebBrowser _browserFromUserAgent(String userAgent) {
    if (userAgent.contains('Edg/') ||
        userAgent.contains('EdgA/') ||
        userAgent.contains('EdgiOS/')) {
      return WebBrowser.edge;
    }
    if (userAgent.contains('Firefox/') || userAgent.contains('FxiOS/')) {
      return WebBrowser.firefox;
    }
    // Samsung Internet carries Chrome's token but has its own menus, so
    // Chrome's steps would be wrong.
    if (userAgent.contains('SamsungBrowser/')) return WebBrowser.other;
    if (userAgent.contains('Chrome/') || userAgent.contains('CriOS/')) {
      return WebBrowser.chrome;
    }
    if (userAgent.contains('Safari/')) return WebBrowser.safari;
    return WebBrowser.other;
  }

  @override
  bool operator ==(Object other) =>
      other is WebPlatform &&
      other.browser == browser &&
      other.os == os &&
      other.inAppBrowser == inAppBrowser &&
      other.hasTouchScreen == hasTouchScreen;

  @override
  int get hashCode => Object.hash(browser, os, inAppBrowser, hasTouchScreen);

  @override
  String toString() =>
      'WebPlatform(browser: ${browser.name}, os: ${os.name}, '
      'inAppBrowser: $inAppBrowser, hasTouchScreen: $hasTouchScreen)';
}

/// Anything else, such as desktop builds or the test host. Treated as having
/// no capture permission model of its own.
final class OtherPlatform extends PlatformInfo {
  const OtherPlatform();
}
