/// Build-time version information injected during deployment.
///
/// Values come from `--web-define` compile-time constants set by
/// [scripts/web_build.dart]. In local development (no defines set) the
/// defaults reflect a local/dev build so developers can distinguish their
/// own builds from deployed ones.
class BuildInfo {
  const BuildInfo({
    required this.version,
    required this.buildNumber,
    required this.environment,
    required this.commitSha,
    required this.deploymentTimestamp,
  });

  /// Reads the compile-time defines baked in by [scripts/web_build.dart].
  ///
  /// Returns sensible defaults when the defines are absent (local dev).
  factory BuildInfo.fromEnvironment() {
    return BuildInfo(
      version: _env('APP_VERSION', defaultValue: '0.0.0'),
      buildNumber: _env('APP_BUILD_NUMBER', defaultValue: '0'),
      environment: _env('APP_ENVIRONMENT', defaultValue: 'development'),
      commitSha: _env('COMMIT_SHA', defaultValue: 'unknown'),
      deploymentTimestamp: _env('DEPLOYMENT_TIMESTAMP', defaultValue: ''),
    );
  }

  /// Semantic version, e.g. `0.0.72`.
  final String version;

  /// Build number, e.g. `72`.
  final String buildNumber;

  /// Deployment environment: `development`, `staging` or `production`.
  final String environment;

  /// Full commit SHA of the deployed revision.
  final String commitSha;

  /// ISO-8601 timestamp of when the bundle was built.
  final String deploymentTimestamp;

  /// Short (7-char) commit SHA for compact display.
  String get shortCommitSha =>
      commitSha.length >= 7 ? commitSha.substring(0, 7) : commitSha;

  /// Whether this is a local (non-deployed) build.
  bool get isLocal => commitSha == 'unknown';

  /// Tags that should be attached to every Sentry event.
  Map<String, String> toSentryTags() => {
    'app.version': version,
    'app.build': buildNumber,
    'app.environment': environment,
    'app.commit': commitSha,
    if (deploymentTimestamp.isNotEmpty) 'app.deployed_at': deploymentTimestamp,
  };

  @override
  String toString() =>
      'BuildInfo(version: $version+$buildNumber, '
      'environment: $environment, commit: $shortCommitSha, '
      'deployed: ${deploymentTimestamp.isNotEmpty ? deploymentTimestamp : "local"})';
}

const _env = String.fromEnvironment;
