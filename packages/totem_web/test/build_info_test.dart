import 'package:flutter_test/flutter_test.dart';
import 'package:totem_web/core/services/build_info.dart';

void main() {
  group('BuildInfo', () {
    test('fromEnvironment returns defaults when no defines are set', () {
      final info = BuildInfo.fromEnvironment();

      expect(info.version, '0.0.0');
      expect(info.buildNumber, '0');
      expect(info.environment, 'development');
      expect(info.commitSha, 'unknown');
      expect(info.deploymentTimestamp, '');
    });

    test('shortCommitSha returns first 7 chars for long SHA', () {
      final info = BuildInfo(
        version: '0.0.1',
        buildNumber: '1',
        environment: 'staging',
        commitSha: 'a1b2c3d4e5f6789012345678901234567890abcd',
        deploymentTimestamp: '2026-07-13T12:00:00.000Z',
      );

      expect(info.shortCommitSha, 'a1b2c3d');
    });

    test('shortCommitSha returns full value when shorter than 7 chars', () {
      final info = BuildInfo(
        version: '0.0.1',
        buildNumber: '1',
        environment: 'development',
        commitSha: 'abc',
        deploymentTimestamp: '',
      );

      expect(info.shortCommitSha, 'abc');
    });

    test('isLocal is true when commitSha is unknown', () {
      final info = BuildInfo(
        version: '0.0.0',
        buildNumber: '0',
        environment: 'development',
        commitSha: 'unknown',
        deploymentTimestamp: '',
      );

      expect(info.isLocal, isTrue);
    });

    test('isLocal is false when commitSha is set', () {
      final info = BuildInfo(
        version: '0.0.72',
        buildNumber: '72',
        environment: 'production',
        commitSha: 'a1b2c3d4e5f6789012345678901234567890abcd',
        deploymentTimestamp: '2026-07-13T12:00:00.000Z',
      );

      expect(info.isLocal, isFalse);
    });

    test('toSentryTags includes all expected keys', () {
      final info = BuildInfo(
        version: '0.0.72',
        buildNumber: '72',
        environment: 'production',
        commitSha: 'a1b2c3d4e5f6789012345678901234567890abcd',
        deploymentTimestamp: '2026-07-13T12:00:00.000Z',
      );

      final tags = info.toSentryTags();

      expect(tags, {
        'app.version': '0.0.72',
        'app.build': '72',
        'app.environment': 'production',
        'app.commit': 'a1b2c3d4e5f6789012345678901234567890abcd',
        'app.deployed_at': '2026-07-13T12:00:00.000Z',
      });
    });

    test('toSentryTags omits deployed_at when timestamp is empty', () {
      final info = BuildInfo(
        version: '0.0.0',
        buildNumber: '0',
        environment: 'development',
        commitSha: 'unknown',
        deploymentTimestamp: '',
      );

      final tags = info.toSentryTags();

      expect(tags, {
        'app.version': '0.0.0',
        'app.build': '0',
        'app.environment': 'development',
        'app.commit': 'unknown',
      });
      expect(tags.containsKey('app.deployed_at'), isFalse);
    });

    test('toString contains key information', () {
      final info = BuildInfo(
        version: '0.0.72',
        buildNumber: '72',
        environment: 'production',
        commitSha: 'a1b2c3d4e5f6789012345678901234567890abcd',
        deploymentTimestamp: '2026-07-13T12:00:00.000Z',
      );

      final str = info.toString();

      expect(str, contains('0.0.72+72'));
      expect(str, contains('production'));
      expect(str, contains('a1b2c3d'));
    });
  });
}
