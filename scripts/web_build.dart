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
const _cloudflareStaticAssetLimit = 25 * 1024 * 1024;
const _flutterVersion = '3.47.7';

Future<void> main() async {
  // scripts/web_build.dart -> repo root is two levels up.
  final repoRoot = File(Platform.script.toFilePath()).parent.parent.path;
  final webDir = '$repoRoot/packages/totem_web';
  final envFile = File('$webDir/.env');

  final flavor = _readEnvironment(envFile);
  final defaultAssetBase = _assetBase[flavor];
  if (defaultAssetBase == null) {
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
  // Each PR has its own CDN. Its absolute asset base keeps all bundle requests
  // on that deployment while Django serves the HTML and API on staging.
  final assetBase = Platform.environment['WEB_ASSET_BASE'] ?? defaultAssetBase;

  // --base-href /room/ : app is served from /room/ on the Django origin.
  // --web-define ASSET_BASE : where flutter_bootstrap.js loads assets from.
  final sentryRelease = Platform.environment['SENTRY_RELEASE'];
  final sentryDist = Platform.environment['SENTRY_DIST'];
  final hasSentryRelease = sentryRelease != null && sentryRelease.isNotEmpty;
  final arguments = [
    'build',
    'web',
    '--wasm',
    if (hasSentryRelease) '--source-maps',
    '--dart-define=WEBRTC_USE_HTML_ELEMENT_VIEW=true',
    '--base-href',
    '/room/',
    '--web-define=ASSET_BASE=$assetBase',
    if (hasSentryRelease) '--dart-define=SENTRY_RELEASE=$sentryRelease',
    if (sentryDist != null && sentryDist.isNotEmpty)
      '--dart-define=SENTRY_DIST=$sentryDist',
  ];
  final fvmFlutterVersion = Platform.environment['FVM_FLUTTER_VERSION'];
  if (fvmFlutterVersion != null && fvmFlutterVersion != _flutterVersion) {
    stderr.writeln(
      'web_build: FVM_FLUTTER_VERSION must be $_flutterVersion, '
      'got $fvmFlutterVersion.',
    );
    exit(1);
  }
  final flutterCommand = fvmFlutterVersion == null ? 'flutter' : 'fvm';
  final flutterArguments = [
    if (fvmFlutterVersion != null) ...['spawn', fvmFlutterVersion],
    ...arguments,
  ];
  await _verifyFlutterVersion(flutterCommand, fvmFlutterVersion);
  final build = await Process.start(
    flutterCommand,
    flutterArguments,
    workingDirectory: webDir,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await build.exitCode;
  if (code != 0) exit(code);

  final buildDirectory = Directory('$webDir/build/web');
  if (hasSentryRelease) _verifyAndReportSourceMaps(buildDirectory);
  _stripInlinedSourceMap(File('${buildDirectory.path}/index.html'));
}

Future<void> _verifyFlutterVersion(
  String flutterCommand,
  String? fvmFlutterVersion,
) async {
  final version = await Process.run(flutterCommand, [
    if (fvmFlutterVersion != null) ...['spawn', fvmFlutterVersion],
    '--version',
    '--machine',
  ]);
  final match = RegExp(
    r'"flutterVersion":\s*"([^"]+)"',
  ).firstMatch(version.stdout as String? ?? '');
  if (version.exitCode != 0 || match?.group(1) != _flutterVersion) {
    stderr.writeln(
      'web_build: requires Flutter $_flutterVersion; '
      'found ${match?.group(1) ?? 'unknown'}.',
    );
    if (version.stderr.toString().isNotEmpty) {
      stderr.write(version.stderr);
    }
    exit(1);
  }
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

void _verifyAndReportSourceMaps(Directory buildDirectory) {
  final sourceMaps =
      buildDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.map'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final hasJavaScriptMap = sourceMaps.any(
    (file) => file.path.endsWith('.js.map'),
  );
  final hasWasmMap = sourceMaps.any((file) => file.path.endsWith('.wasm.map'));

  if (!hasJavaScriptMap || !hasWasmMap) {
    stderr.writeln(
      'web_build: expected JavaScript and WebAssembly source maps in '
      '${buildDirectory.path}.',
    );
    exit(1);
  }

  for (final sourceMap in sourceMaps) {
    final size = sourceMap.lengthSync();
    final exceedsLimit = size > _cloudflareStaticAssetLimit;
    print(
      'web_build: ${sourceMap.path} '
      '(${(size / (1024 * 1024)).toStringAsFixed(2)} MiB)'
      '${exceedsLimit ? ' exceeds Cloudflare\'s 25 MiB static asset limit' : ''}',
    );
  }
}

// flutter.js is inlined into the Django-served index.html, so its relative
// `//# sourceMappingURL=flutter.js.map` comment resolves against /room/ -- which
// makes dev tools GET /room/flutter.js.map from Django instead of the Worker.
// Flutter has no flag to omit the comment, so strip it for source-map builds
// too. Removing the exact substring (rather than the whole line) is safe even
// if a minifier ever puts the comment on the same line as real code.
void _stripInlinedSourceMap(File index) {
  final html = index.readAsStringSync();
  index.writeAsStringSync(html.replaceAll(_sourceMapMarker, ''));
}
