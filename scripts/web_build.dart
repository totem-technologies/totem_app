// Build the totem_web Flutter web bundle the way it deploys: mounted at /room/
// on the Django origin, with assets fetched from a separate CDN origin via
// ASSET_BASE.
//
// Runtime config (.env) is composed SEPARATELY — `make env-<flavor>` locally, or
// the setup-environment / build-web actions in CI — so a flavor is chosen in
// exactly one place. This reads the composed ENVIRONMENT back out, maps it to
// the matching CDN, then builds. If .env hasn't been composed it errors rather
// than silently shipping the wrong config.
//
// Version info is injected as `--web-define` compile-time constants so the
// running app can report its exact commit, build number and deploy timestamp.
// CI passes GITHUB_SHA automatically; local builds fall back to `git rev-parse`.
//
// Usage: dart scripts/web_build.dart   (run `make env-<flavor>` first)

// OK to use print
// ignore_for_file: avoid_print

import 'dart:io';

// ENVIRONMENT -> the CDN the Flutter loader fetches assets from.
const _assetBase = {
  'development': 'http://localhost:5173/',
  'staging': 'https://totem-web-staging.lopkerk.workers.dev/',
  'production': 'https://totem-web-production.lopkerk.workers.dev/',
};

const _sourceMapMarker = '//# sourceMappingURL=flutter.js.map';

Future<void> main() async {
  // scripts/web_build.dart -> repo root is two levels up.
  final repoRoot = File(Platform.script.toFilePath()).parent.parent.path;
  final webDir = '$repoRoot/packages/totem_web';
  final envFile = File('$webDir/.env');

  final flavor = _readEnvironment(envFile);
  final assetBase = _assetBase[flavor];
  if (assetBase == null) {
    stderr
      ..writeln(
        "web_build: ${envFile.path} is missing or has no known "
        "ENVIRONMENT (got: '${flavor ?? ''}').",
      )
      ..writeln(
        '           compose it first: make env-dev | env-staging | env-prod',
      );
    exit(1);
  }

  final commitSha = _resolveCommitSha(repoRoot);
  final deployTimestamp = DateTime.now().toUtc().toIso8601String();
  final pubspec = _readPubspec('$webDir/pubspec.yaml');

  print('web_build: environment=$flavor commit=$commitSha');

  // --base-href /room/ : app is served from /room/ on the Django origin.
  // --web-define ASSET_BASE : where flutter_bootstrap.js loads assets from.
  // --web-define COMMIT_SHA / APP_VERSION / etc. : build-info constants.
  final build = await Process.start(
    'flutter',
    [
      'build',
      'web',
      '--wasm',
      '--base-href',
      '/room/',
      '--web-define=ASSET_BASE=$assetBase',
      '--web-define=COMMIT_SHA=$commitSha',
      '--web-define=DEPLOYMENT_TIMESTAMP=$deployTimestamp',
      '--web-define=APP_VERSION=${pubspec.version}',
      '--web-define=APP_BUILD_NUMBER=${pubspec.buildNumber}',
      '--web-define=APP_ENVIRONMENT=$flavor',
    ],
    workingDirectory: webDir,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await build.exitCode;
  if (code != 0) exit(code);

  _stripInlinedSourceMap(File('$webDir/build/web/index.html'));
}

String? _readEnvironment(File envFile) {
  if (!envFile.existsSync()) return null;
  for (final line in envFile.readAsLinesSync()) {
    if (!line.startsWith('ENVIRONMENT=')) continue;
    return line
        .substring('ENVIRONMENT='.length)
        .replaceAll(RegExp('[\'" ]'), '');
  }
  return null;
}

// flutter.js is inlined into the Django-served index.html, so its relative
// `//# sourceMappingURL=flutter.js.map` comment resolves against /room/ -- which
// makes dev tools GET /room/flutter.js.map from Django (its asset proxy is
// dev-only and 500s in prod). The map isn't shipped and Flutter has no flag to
// omit the comment, so strip the comment itself. Removing the exact substring
// (rather than the whole line) is safe even if a minifier ever puts the comment
// on the same line as real code.
void _stripInlinedSourceMap(File index) {
  final html = index.readAsStringSync();
  index.writeAsStringSync(html.replaceAll(_sourceMapMarker, ''));
}

/// Resolves the commit SHA of the current checkout.
///
/// Precedence:
///  1. `COMMIT_SHA` env var (set by CI, e.g. GITHUB_SHA is mapped in the
///     build-web action)
///  2. `git rev-parse HEAD` (local builds)
String _resolveCommitSha(String repoRoot) {
  final fromEnv = Platform.environment['COMMIT_SHA'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  try {
    final result = Process.runSync(
      'git',
      ['rev-parse', 'HEAD'],
      workingDirectory: repoRoot,
      runInShell: true,
    );
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {
    // fall through
  }
  return 'unknown';
}

/// Parses the version line from pubspec.yaml into a [PubspecVersion].
_PubspecVersion _readPubspec(String path) {
  const versionRe = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$',
    multiLine: true,
  );
  final content = File(path).readAsStringSync();
  final match = versionRe.firstMatch(content);
  if (match == null) {
    stderr.writeln('web_build: could not parse version from $path');
    exit(1);
  }
  return _PubspecVersion(
    version: match.group(1)!,
    buildNumber: match.group(2)!,
  );
}

class _PubspecVersion {
  const _PubspecVersion({required this.version, required this.buildNumber});
  final String version;
  final String buildNumber;
}
