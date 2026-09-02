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

  // --base-href /room/ : app is served from /room/ on the Django origin.
  // --web-define ASSET_BASE : where flutter_bootstrap.js loads assets from.
  final build = await Process.start(
    'flutter',
    [
      'build',
      'web',
      '--wasm',
      '--base-href',
      '/room/',
      '--web-define=ASSET_BASE=$assetBase',
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
