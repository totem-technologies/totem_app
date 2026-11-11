import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../web_build.dart';

void main() {
  test('selects Flutter from the Dart SDK rather than PATH or FVM', () {
    final separator = Platform.pathSeparator;
    for (final root in ['/ci/flutter', '/home/user/fvm/versions/3.50.0']) {
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

  test('requires a valid Flutter version in the root FVM configuration', () {
    check(
      expectedFlutterVersionFromConfig('{"flutter":"3.50.0-0.2.pre"}'),
    ).equals('3.50.0-0.2.pre');
    for (final config in <String?>[
      null,
      '',
      '{',
      'null',
      '[]',
      '{}',
      '{"flutter":null}',
      '{"flutter":123}',
      '{"flutter":""}',
      '{"flutter":"  "}',
      '{"flutter":"stable"}',
      '{"flutter":"3.50"}',
    ]) {
      check(
        () => expectedFlutterVersionFromConfig(config),
      ).throws<StateError>();
    }
  });

  test('detects installed Flutter version mismatches against FVM config', () {
    final expected = expectedFlutterVersionFromConfig('{"flutter":"3.50.0"}');
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
