import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/shared/routing.dart';

void main() {
  group('RoutingUtils.parseTotemDeepLink', () {
    test('parses share link with query params', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://www.totem.org/spaces/event/tmf470ckp?utm_source=app&utm_medium=share',
      );
      expect(result, '/spaces/event/tmf470ckp');
    });

    test('parses share link without www', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://totem.org/spaces/event/abc123',
      );
      expect(result, '/spaces/event/abc123');
    });

    test('parses full space+session link', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://totem.org/spaces/my-space/event/abc123',
      );
      expect(result, '/spaces/my-space/session/abc123');
    });

    test('parses space detail link', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://totem.org/spaces/my-space',
      );
      expect(result, '/spaces/my-space');
    });

    test('returns null for external domains', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://external.com/spaces/event/abc',
      );
      expect(result, isNull);
    });

    test('parses staging domain link', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://totem.kbl.io/spaces/event/abc123',
      );
      expect(result, '/spaces/event/abc123');
    });

    test('parses blog link', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://totem.org/blog/my-post',
      );
      expect(result, '/blog/my-post');
    });

    test('parses keeper link', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://totem.org/keeper/john',
      );
      expect(result, '/keeper/john');
    });

    test('returns null for root path', () {
      final result = RoutingUtils.parseTotemDeepLink('https://totem.org/');
      expect(result, isNull);
    });

    test('returns null for empty path', () {
      final result = RoutingUtils.parseTotemDeepLink('https://totem.org');
      expect(result, isNull);
    });

    test('returns null for unrecognized path', () {
      final result = RoutingUtils.parseTotemDeepLink(
        'https://totem.org/unknown/path',
      );
      expect(result, isNull);
    });
  });
}
