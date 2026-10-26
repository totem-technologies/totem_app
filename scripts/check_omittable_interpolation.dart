// Checks that no string interpolates an `Omittable` API field.
//
// Generated API models wrap optional fields in `Omittable`, and Dart accepts
// any object in `${...}`, so `'with ${author.name}'` compiles and renders
// "with Omittable(Ada)". Read the field with `.value` instead. Only resolved
// types tell an `Omittable` apart from a plain field, hence the analyzer.

// OK to use print
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// The library code checked by default.
const defaultRoots = [
  'packages/totem_core/lib',
  'packages/totem_app/lib',
  'packages/totem_web/lib',
];

/// Returns `path:line: expression` for every interpolated `Omittable` in the
/// Dart files under [roots].
Future<List<String>> findOmittableInterpolations(
  List<String> roots, {
  List<String>? files,
}) async {
  final collection = AnalysisContextCollection(
    includedPaths: [for (final root in roots) Directory(root).absolute.path],
    sdkPath: _dartSdkPath(),
  );
  final requestedFiles = files == null
      ? null
      : files
            .where((path) => path.endsWith('.dart') && File(path).existsSync())
            .map((path) => File(path).absolute.path)
            .toSet();
  final found = <String>[];
  for (final context in collection.contexts) {
    final analyzedFiles = requestedFiles ?? context.contextRoot.analyzedFiles();
    for (final path in analyzedFiles) {
      if (!path.endsWith('.dart') || !context.contextRoot.isAnalyzed(path)) {
        continue;
      }
      final result = await context.currentSession.getResolvedUnit(path);
      if (result is! ResolvedUnitResult) continue;
      final visitor = _OmittableInterpolations();
      result.unit.accept(visitor);
      for (final expression in visitor.found) {
        final line = result.lineInfo.getLocation(expression.offset).lineNumber;
        found.add('$path:$line: ${expression.toSource()}');
      }
    }
  }
  return found;
}

/// Under `flutter test` the running executable isn't the Dart VM, so the
/// analyzer can't find the SDK by itself; Flutter ships one in its cache.
String? _dartSdkPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return null;
  final sdk = Directory('$flutterRoot/bin/cache/dart-sdk');
  return sdk.existsSync() ? sdk.path : null;
}

class _OmittableInterpolations extends RecursiveAstVisitor<void> {
  final found = <Expression>[];

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    if (node.expression.staticType?.element?.name == 'Omittable') {
      found.add(node.expression);
    }
    super.visitInterpolationExpression(node);
  }
}

Future<void> main(List<String> args) async {
  var workspace = Directory.current.path;
  final files = <String>[];
  var readingFiles = false;
  for (final arg in args) {
    if (arg.startsWith('--workspace=')) {
      workspace = arg.substring('--workspace='.length);
    } else if (arg == '--files') {
      readingFiles = true;
    } else if (readingFiles) {
      files.add(arg);
    } else {
      throw ArgumentError('Usage: [--workspace=<path>] [--files <path...>]');
    }
  }
  final roots = args.isEmpty
      ? defaultRoots
      : defaultRoots.map((root) => '$workspace/$root').toList();
  final found = await findOmittableInterpolations(
    roots,
    files: files.isEmpty
        ? null
        : files.map((path) => '$workspace/$path').toList(),
  );
  for (final message in found) {
    print('$message (read it with .value)');
  }
  if (found.isNotEmpty) exit(1);
  print('No interpolated Omittable fields.');
}
