import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../web_build.dart';

void main() {
  test('selects Flutter from the Dart SDK rather than PATH', () {
    final separator = Platform.pathSeparator;
    for (final root in ['/ci/flutter', '/home/user/custom/versions/3.50.0']) {
      final nativeRoot = root.replaceAll('/', separator);
      final dart =
          '$nativeRoot${separator}bin${separator}cache${separator}dart-sdk${separator}bin${separator}dart';
      final flutter =
          '$nativeRoot${separator}bin${separator}flutter${Platform.isWindows ? '.bat' : ''}';
      check(flutterForDart(dart, (path) => path == flutter)).equals(flutter);
      check(() => flutterForDart(dart, (_) => false)).throws<StateError>();
    }

    check(
      () => flutterForDart(
        '${separator}usr${separator}bin${separator}dart',
        (_) => true,
      ),
    ).throws<StateError>();
  });

  test('rejects missing or unknown web environment configuration', () {
    for (final lines in <List<String>>[
      [],
      ['API_URL=x'],
      ['ENVIRONMENT=unknown'],
    ]) {
      check(assetBaseForEnvironment(readEnvironment(lines))).isNull();
    }
    check(
      assetBaseForEnvironment(readEnvironment(['ENVIRONMENT="staging"'])),
    ).equals('https://totem-web-staging.lopkerk.workers.dev/');
  });

  test('requires a valid Flutter version in the root version file', () {
    check(expectedFlutterVersionFromConfig('3.50.0\n')).equals('3.50.0');
    for (final config in <String?>[
      null,
      '',
      '{"flutter":"3.50.0"}',
      '  ',
      'stable',
      '3.50',
    ]) {
      check(
        () => expectedFlutterVersionFromConfig(config),
      ).throws<StateError>();
    }
  });

  test('detects installed Flutter version mismatches against version file', () {
    final expected = expectedFlutterVersionFromConfig('3.50.0');
    check(
      installedVersionMatches(expected, 0, '{"flutterVersion": "3.50.0"}'),
    ).isTrue();
    check(
      installedVersionMatches(expected, 0, '{"flutterVersion": "3.44.0"}'),
    ).isFalse();
    check(installedVersionMatches(expected, 0, '{}')).isFalse();
    check(
      installedVersionMatches(expected, 1, '{"flutterVersion": "3.50.0"}'),
    ).isFalse();
  });
}
