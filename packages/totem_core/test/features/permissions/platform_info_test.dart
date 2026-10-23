import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

void main() {
  group('WebPlatform.fromUserAgent', () {
    final cases = <String, (String, WebBrowser, HostOs, bool)>{
      'Chrome on macOS': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
        WebBrowser.chrome,
        HostOs.macos,
        false,
      ),
      'Edge on Windows': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 '
            'Edg/129.0.0.0',
        WebBrowser.edge,
        HostOs.windows,
        false,
      ),
      'Firefox on macOS': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:131.0) '
            'Gecko/20100101 Firefox/131.0',
        WebBrowser.firefox,
        HostOs.macos,
        false,
      ),
      'Firefox on Android': (
        'Mozilla/5.0 (Android 14; Mobile; rv:131.0) Gecko/131.0 '
            'Firefox/131.0',
        WebBrowser.firefox,
        HostOs.android,
        false,
      ),
      'Safari on macOS': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
            'Safari/605.1.15',
        WebBrowser.safari,
        HostOs.macos,
        false,
      ),
      'Safari on iOS': (
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
            'Mobile/15E148 Safari/604.1',
        WebBrowser.safari,
        HostOs.ios,
        false,
      ),
      'Chrome on iOS': (
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/129.0.6668.69 '
            'Mobile/15E148 Safari/604.1',
        WebBrowser.chrome,
        HostOs.ios,
        false,
      ),
      'Chrome on Android': (
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36',
        WebBrowser.chrome,
        HostOs.android,
        false,
      ),
      'Chrome on Linux': (
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
        WebBrowser.chrome,
        HostOs.linux,
        false,
      ),
      'WS5: Instagram in-app browser on iOS': (
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 '
            'Instagram 341.0.0.29.104 (iPhone14,5; iOS 17_5; en_US; en)',
        WebBrowser.other,
        HostOs.ios,
        true,
      ),
      'WS5: generic WKWebView on iOS (no Safari token)': (
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
        WebBrowser.other,
        HostOs.ios,
        true,
      ),
      'WS5: Facebook in-app browser on Android': (
        'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP2A.240805.005; wv) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
            'Chrome/127.0.6533.103 Mobile Safari/537.36 '
            '[FB_IAB/FB4A;FBAV/478.0.0.42.115;]',
        WebBrowser.chrome,
        HostOs.android,
        true,
      ),
      'Samsung Internet is not Chrome': (
        'Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 '
            '(KHTML, like Gecko) SamsungBrowser/25.0 Chrome/121.0.0.0 '
            'Mobile Safari/537.36',
        WebBrowser.other,
        HostOs.android,
        false,
      ),
    };

    for (final MapEntry(key: name, value: (ua, browser, os, inApp))
        in cases.entries) {
      test(name, () {
        final info = WebPlatform.fromUserAgent(ua);
        check(info.browser).equals(browser);
        check(info.os).equals(os);
        check(info.inAppBrowser).equals(inApp);
      });
    }
  });

  group('iPadOS desktop-class Safari', () {
    // iPadOS 13+ sends the macOS user agent by default.
    const ua =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
        'Safari/605.1.15';

    test('reports macOS, with touch only as a hint', () {
      final info = WebPlatform.fromUserAgent(ua, maxTouchPoints: 5);
      check(info.os).equals(HostOs.macos);
      check(info.browser).equals(WebBrowser.safari);
      check(info.inAppBrowser).isFalse();
      check(info.hasTouchScreen).isTrue();
    });

    test('a Mac reports no touchscreen', () {
      check(WebPlatform.fromUserAgent(ua).hasTouchScreen).isFalse();
    });
  });
}
