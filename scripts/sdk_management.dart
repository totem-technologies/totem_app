import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 2 || !{'setup', 'doctor'}.contains(args.first)) {
    stderr.writeln(
      'Usage: dart scripts/sdk_management.dart setup|doctor <flutter executable>',
    );
    exitCode = 2;
    return;
  }

  final root = File.fromUri(Platform.script).parent.parent;
  final pin = (await File.fromUri(
    root.uri.resolve('.flutter-version'),
  ).readAsString()).trim();
  final flutter = args[1];
  final result = await Process.run(flutter, [
    '--version',
    '--machine',
  ], workingDirectory: root.path);
  if (result.exitCode != 0) {
    stderr.writeln('Could not run Flutter at "$flutter": ${result.stderr}');
    exitCode = result.exitCode;
    return;
  }

  final Map<String, Object?> metadata;
  try {
    metadata = jsonDecode(result.stdout as String) as Map<String, Object?>;
  } on FormatException catch (error) {
    stderr.writeln('Flutter returned invalid version metadata: $error');
    exitCode = 1;
    return;
  }

  final version = metadata['frameworkVersion'];
  if (version != pin) {
    stderr.writeln(
      'Expected Flutter $pin from .flutter-version, found $version. Select the pinned SDK and retry.',
    );
    exitCode = 1;
    return;
  }

  final flutterRoot = metadata['flutterRoot'] as String?;
  if (flutterRoot == null || !await _dartMatchesFlutter(flutterRoot)) {
    stderr.writeln(
      'The Dart executable running this script does not belong to Flutter $version. Put that Flutter installation first on PATH.',
    );
    exitCode = 1;
    return;
  }

  final dartVersion = _reportedDartVersion(Platform.version);
  final expectedDart = _expectedDartVersion(
    metadata['dartSdkVersion'] as String?,
  );
  if (dartVersion != expectedDart) {
    stderr.writeln(
      'This script is running Dart $dartVersion, but Flutter $version bundles Dart $expectedDart.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Flutter $version ($flutter); Dart $dartVersion (${Platform.resolvedExecutable})',
  );
  if (args.first == 'doctor') {
    final doctor = await Process.start(
      flutter,
      ['doctor'],
      workingDirectory: root.path,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await doctor.exitCode;
  }
}

Future<bool> _dartMatchesFlutter(String flutterRoot) async {
  final actual = await File(Platform.resolvedExecutable).resolveSymbolicLinks();
  final candidates = [
    '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}dart',
    '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin${Platform.pathSeparator}dart',
  ];
  for (final candidate in candidates) {
    final file = File(candidate);
    if (await file.exists() && await file.resolveSymbolicLinks() == actual) {
      return true;
    }
  }
  return false;
}

String? _reportedDartVersion(String version) => RegExp(
  r'^(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)',
).firstMatch(version)?.group(1);

String? _expectedDartVersion(String? version) {
  if (version == null) return null;
  return RegExp(r'\(build ([^)]+)\)').firstMatch(version)?.group(1) ??
      version.split(' ').first;
}
