// Incremental validation for Git hooks. Run from the repository root.
//
// `pre-commit` validates staged Dart source only. `pre-push` derives the files
// introduced by every pushed ref and validates the affected workspace packages.

// OK to use print
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

enum ChangeKind { added, copied, modified, renamed, deleted }

class GitChange {
  const GitChange(this.kind, this.path, {this.oldPath});

  final ChangeKind kind;
  final String path;
  final String? oldPath;
}

class WorkspacePackage {
  const WorkspacePackage({
    required this.name,
    required this.path,
    required this.localDependencies,
  });

  final String name;
  final String path;
  final Set<String> localDependencies;
}

class Workspace {
  const Workspace(this.packages);

  final List<WorkspacePackage> packages;

  Set<String> dependentsOf(String package) {
    final found = <String>{};
    final pending = <String>[package];
    while (pending.isNotEmpty) {
      final dependency = pending.removeLast();
      for (final candidate in packages) {
        if (candidate.localDependencies.contains(dependency) &&
            found.add(candidate.name)) {
          pending.add(candidate.name);
        }
      }
    }
    return found;
  }

  WorkspacePackage? packageForPath(String path) {
    for (final package in packages) {
      if (path == package.path || path.startsWith('${package.path}/')) {
        return package;
      }
    }
    return null;
  }

  static Workspace fromPubspecs(Map<String, String> pubspecs) {
    final root = pubspecs['pubspec.yaml'];
    if (root == null) throw StateError('Missing root pubspec.yaml');
    final paths = _workspacePaths(root);
    final namesByPath = <String, String>{
      for (final path in paths)
        if (pubspecs['$path/pubspec.yaml'] case final content?)
          path: _packageName(content),
    };
    final names = namesByPath.values.toSet();
    return Workspace([
      for (final path in paths)
        if (pubspecs['$path/pubspec.yaml'] case final content?)
          WorkspacePackage(
            name: namesByPath[path]!,
            path: path,
            localDependencies: _localDependencies(content, names),
          ),
    ]);
  }
}

class ValidationPlan {
  ValidationPlan({
    required this.workspace,
    this.full = false,
    this.needsPubGet = false,
    Set<String>? analyzePackages,
    Set<String>? testPackages,
    Set<String>? sourceFiles,
    this.runMediaCheck = false,
    this.runInterpolationCheck = false,
    this.runScriptTests = false,
    this.runBenchmarkNodeTests = false,
  }) : analyzePackages = analyzePackages ?? <String>{},
       testPackages = testPackages ?? <String>{},
       sourceFiles = sourceFiles ?? <String>{};

  final Workspace workspace;
  bool full;
  bool needsPubGet;
  final Set<String> analyzePackages;
  final Set<String> testPackages;
  final Set<String> sourceFiles;
  bool runMediaCheck;
  bool runInterpolationCheck;
  bool runScriptTests;
  bool runBenchmarkNodeTests;

  bool get hasWork =>
      full ||
      analyzePackages.isNotEmpty ||
      testPackages.isNotEmpty ||
      runMediaCheck ||
      runInterpolationCheck ||
      runScriptTests ||
      runBenchmarkNodeTests;

  void requireFullValidation({bool requiresPubGet = false}) {
    full = true;
    needsPubGet = needsPubGet || requiresPubGet;
    analyzePackages
      ..clear()
      ..addAll(workspace.packages.map((package) => package.name));
    testPackages
      ..clear()
      ..addAll(workspace.packages.map((package) => package.name));
    runMediaCheck = true;
    runInterpolationCheck = true;
    runScriptTests = true;
    runBenchmarkNodeTests = true;
  }
}

/// Deterministically classifies changed paths. Unknown root-level files are
/// conservative: they require comprehensive validation rather than a skip.
ValidationPlan planValidation(
  Workspace workspace,
  Iterable<GitChange> changes,
) {
  final plan = ValidationPlan(workspace: workspace);
  final directPackages = <String>{};

  for (final change in changes) {
    final path = change.path.replaceAll(r'\', '/');
    if (_isGeneratedOrCachePath(path)) continue;
    final package = workspace.packageForPath(path);
    if (package != null) {
      directPackages.add(package.name);
      if (_isDefaultLintSource(path)) {
        plan
          ..sourceFiles.add(path)
          ..runMediaCheck = true
          ..runInterpolationCheck = true;
      }
      if (path == '${package.path}/pubspec.yaml' ||
          path == '${package.path}/pubspec.lock') {
        plan.requireFullValidation(requiresPubGet: true);
      }
      continue;
    }

    if (_isDocumentation(path)) continue;
    if (path == 'pubspec.yaml' || path == 'pubspec.lock') {
      plan.requireFullValidation(requiresPubGet: true);
      continue;
    }
    if (path.startsWith('scripts/benchmark/')) {
      plan.runBenchmarkNodeTests = true;
      continue;
    }
    if (path.startsWith('scripts/test/') ||
        path == 'scripts/check_media_boundary.dart' ||
        path == 'scripts/check_omittable_interpolation.dart' ||
        path == 'scripts/git_checks.dart') {
      plan.runScriptTests = true;
      continue;
    }
    if (_isSharedConfiguration(path)) {
      plan.requireFullValidation();
      continue;
    }

    // A removed workspace package is not present in the current metadata.
    if (path.startsWith('packages/')) {
      plan.requireFullValidation();
      continue;
    }
    plan.requireFullValidation();
  }

  if (plan.full) return plan;
  for (final packageName in directPackages) {
    plan
      ..analyzePackages.add(packageName)
      ..testPackages.add(packageName);
    if (packageName == 'totem_core') {
      plan.analyzePackages.addAll(workspace.dependentsOf(packageName));
    }
  }
  return plan;
}

bool _isGeneratedOrCachePath(String path) {
  const excludedDirectories = {
    'build',
    '.dart_tool',
    '.pub',
    '.pub-cache',
    'node_modules',
  };
  return path.split('/').any(excludedDirectories.contains);
}

bool _isDocumentation(String path) =>
    path.endsWith('.md') ||
    path.endsWith('.txt') ||
    path.startsWith('docs/') ||
    path.startsWith('screenshots/');

bool _isSharedConfiguration(String path) =>
    path == 'pubspec.yaml' ||
    path == 'pubspec.lock' ||
    path == '.fvmrc' ||
    path == 'Makefile' ||
    path == 'analysis_options.yaml' ||
    path == 'build.yaml' ||
    path == 'l10n.yaml' ||
    path.startsWith('.githooks/') ||
    path.startsWith('.github/') ||
    path.startsWith('config/') ||
    path.startsWith('tool/');

List<String> _workspacePaths(String content) {
  final paths = <String>[];
  var inWorkspace = false;
  for (final line in const LineSplitter().convert(content)) {
    if (RegExp(r'^workspace:\s*$').hasMatch(line)) {
      inWorkspace = true;
      continue;
    }
    if (inWorkspace && RegExp(r'^[^\s#]').hasMatch(line)) break;
    final match = RegExp(r'^\s*-\s+([^\s#]+)').firstMatch(line);
    if (inWorkspace && match != null) paths.add(match.group(1)!);
  }
  return paths;
}

String _packageName(String content) {
  final match = RegExp(
    r'^name:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(content);
  if (match == null) throw StateError('Missing package name in pubspec.yaml');
  return match.group(1)!;
}

Set<String> _localDependencies(String content, Set<String> workspaceNames) {
  final dependencies = <String>{};
  var inDependencies = false;
  String? dependency;
  for (final line in const LineSplitter().convert(content)) {
    if (RegExp(
      r'^(dependencies|dev_dependencies|dependency_overrides):\s*$',
    ).hasMatch(line)) {
      inDependencies = line.startsWith('dependencies:');
      dependency = null;
      continue;
    }
    if (RegExp(r'^[^\s#]').hasMatch(line)) {
      inDependencies = false;
      dependency = null;
      continue;
    }
    final dependencyMatch = RegExp(r'^  ([\w-]+):').firstMatch(line);
    if (inDependencies && dependencyMatch != null) {
      dependency = dependencyMatch.group(1);
      continue;
    }
    if (inDependencies &&
        dependency != null &&
        RegExp(r'^    path:\s+').hasMatch(line) &&
        workspaceNames.contains(dependency)) {
      dependencies.add(dependency);
    }
  }
  return dependencies;
}

List<GitChange> parseNameStatus(String output) {
  final fields = output.split('\u0000');
  final changes = <GitChange>[];
  for (var index = 0; index < fields.length;) {
    final status = fields[index++];
    if (status.isEmpty) continue;
    final kind = switch (status[0]) {
      'A' => ChangeKind.added,
      'C' => ChangeKind.copied,
      'M' => ChangeKind.modified,
      'R' => ChangeKind.renamed,
      'D' => ChangeKind.deleted,
      _ => throw FormatException('Unsupported git change status: $status'),
    };
    if (kind == ChangeKind.copied || kind == ChangeKind.renamed) {
      if (index + 1 >= fields.length) {
        throw const FormatException(
          'Missing paths after git rename/copy status',
        );
      }
      final oldPath = fields[index++];
      final path = fields[index++];
      changes.add(GitChange(kind, path, oldPath: oldPath));
    } else {
      if (index >= fields.length) {
        throw const FormatException('Missing path after git change status');
      }
      changes.add(GitChange(kind, fields[index++]));
    }
  }
  return changes;
}

class RefUpdate {
  const RefUpdate({
    required this.localRef,
    required this.localSha,
    required this.remoteRef,
    required this.remoteSha,
  });

  final String localRef;
  final String localSha;
  final String remoteRef;
  final String remoteSha;

  bool get isDeletion => _isZeroSha(localSha);
  bool get isNewBranch => _isZeroSha(remoteSha);
}

List<RefUpdate> parseRefUpdates(String input) => [
  for (final line in const LineSplitter().convert(input))
    if (line.trim().isNotEmpty)
      switch (line.trim().split(RegExp(r'\s+'))) {
        [final localRef, final localSha, final remoteRef, final remoteSha] =>
          RefUpdate(
            localRef: localRef,
            localSha: localSha,
            remoteRef: remoteRef,
            remoteSha: remoteSha,
          ),
        _ => throw FormatException('Invalid pre-push ref update: $line'),
      },
];

bool _isZeroSha(String sha) => RegExp(r'^0+$').hasMatch(sha);

class CheckCommand {
  const CheckCommand(this.executable, this.arguments, {this.workingDirectory});

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

List<CheckCommand> prePushCommands(
  ValidationPlan plan, {
  required bool workspaceResolved,
}) {
  if (!plan.hasWork) return const [];
  final commands = <CheckCommand>[];
  if (plan.needsPubGet || !workspaceResolved) {
    commands.add(const CheckCommand('flutter', ['pub', 'get']));
  }
  if (plan.full) {
    commands.addAll(const [
      CheckCommand('make', ['format-check']),
      CheckCommand('make', ['lint']),
      CheckCommand('make', [
        '--jobs=2',
        'test-core',
        'test-app',
        'test-web',
        'test-benchmark',
        'test-widgetbook',
        'test-scripts',
        'TEST_PUB=--no-pub',
      ]),
    ]);
    return commands;
  }

  if (plan.runMediaCheck) {
    commands.add(
      CheckCommand('dart', [
        'scripts/check_media_boundary.dart',
        '--files',
        ...plan.sourceFiles,
      ]),
    );
  }
  if (plan.runInterpolationCheck) {
    commands.add(
      CheckCommand('dart', [
        'scripts/check_omittable_interpolation.dart',
        '--files',
        ...plan.sourceFiles,
      ]),
    );
  }
  for (final package in plan.workspace.packages) {
    if (plan.analyzePackages.contains(package.name)) {
      commands.add(
        CheckCommand('flutter', [
          'analyze',
          '--no-pub',
        ], workingDirectory: package.path),
      );
    }
  }
  for (final package in plan.workspace.packages) {
    if (plan.testPackages.contains(package.name)) {
      commands.add(
        CheckCommand('make', [
          'test-${package.name.replaceFirst('totem_', '')}',
          'TEST_PUB=--no-pub',
        ]),
      );
    }
  }
  if (plan.runScriptTests) {
    commands.add(
      const CheckCommand('make', ['test-scripts', 'TEST_PUB=--no-pub']),
    );
  }
  if (plan.runBenchmarkNodeTests &&
      !plan.testPackages.contains('totem_benchmark')) {
    commands.add(
      const CheckCommand('node', [
        '--test',
        'scripts/benchmark/metrics.test.mjs',
      ]),
    );
  }
  return commands;
}

abstract interface class CommandRunner {
  Future<int> run(CheckCommand command);
}

class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner();

  @override
  Future<int> run(CheckCommand command) async {
    print('> $command');
    final process = await Process.start(
      command.executable,
      command.arguments,
      workingDirectory: command.workingDirectory,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}

Future<void> runCommands(
  Iterable<CheckCommand> commands,
  CommandRunner runner,
) async {
  for (final command in commands) {
    if (await runner.run(command) case final exitCode when exitCode != 0) {
      throw ProcessException(
        command.executable,
        command.arguments,
        'Validation failed: $command',
        exitCode,
      );
    }
  }
}

class GitClient {
  const GitClient();

  Future<List<GitChange>> stagedChanges() async {
    final output = await _gitText([
      'diff',
      '--cached',
      '--name-status',
      '-z',
      '--find-renames',
      '--diff-filter=ACMR',
    ]);
    return parseNameStatus(output);
  }

  Future<List<GitChange>> changesBetween(String base, String target) async {
    final output = await _gitText([
      'diff',
      '--name-status',
      '-z',
      '--find-renames',
      '$base..$target',
    ]);
    return parseNameStatus(output);
  }

  Future<bool> objectExists(String sha) async =>
      (await Process.run('git', [
        'cat-file',
        '-e',
        '$sha^{commit}',
      ])).exitCode ==
      0;

  Future<String?> defaultRemoteBranch() async {
    final result = await Process.run('git', [
      'for-each-ref',
      '--format=%(symref)',
      'refs/remotes/*/HEAD',
    ]);
    if (result.exitCode != 0) return null;
    final ref = result.stdout.toString().trim();
    return ref.isEmpty ? null : ref;
  }

  Future<String?> mergeBase(String first, String second) async {
    final result = await Process.run('git', ['merge-base', first, second]);
    if (result.exitCode != 0) return null;
    final sha = result.stdout.toString().trim();
    return sha.isEmpty ? null : sha;
  }

  Future<List<int>> indexFile(String path) async {
    final result = await Process.run(
      'git',
      ['show', ':$path'],
      stdoutEncoding: null,
      stderrEncoding: null,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        ['show', ':$path'],
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return result.stdout as List<int>;
  }

  Future<void> checkoutIndex(String destination) async {
    final result = await Process.run('git', [
      'checkout-index',
      '--all',
      '--prefix=$destination${Platform.pathSeparator}',
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        ['checkout-index', '--all'],
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }

  Future<String> _gitText(List<String> arguments) async {
    final result = await Process.run(
      'git',
      arguments,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return result.stdout as String;
  }
}

Future<Workspace> loadWorkspace() async {
  final root = await File('pubspec.yaml').readAsString();
  final paths = _workspacePaths(root);
  final pubspecs = <String, String>{'pubspec.yaml': root};
  for (final path in paths) {
    pubspecs['$path/pubspec.yaml'] = await File(
      '$path/pubspec.yaml',
    ).readAsString();
  }
  return Workspace.fromPubspecs(pubspecs);
}

bool hasWorkspaceResolution(Workspace workspace) {
  final packageConfig = File('.dart_tool/package_config.json');
  final lockfile = File('pubspec.lock');
  if (!packageConfig.existsSync() || !lockfile.existsSync()) return false;

  final resolvedAt = packageConfig.lastModifiedSync();
  final manifests = [
    lockfile,
    File('pubspec.yaml'),
    for (final package in workspace.packages)
      File('${package.path}/pubspec.yaml'),
  ];
  return manifests.every(
    (manifest) =>
        manifest.existsSync() &&
        !manifest.lastModifiedSync().isAfter(resolvedAt),
  );
}

Future<void> checkStagedFormatting(
  List<GitChange> changes,
  GitClient git,
) async {
  final dartFiles = changes
      .where(
        (change) =>
            change.path.endsWith('.dart') &&
            !_isGeneratedOrCachePath(change.path.replaceAll(r'\', '/')),
      )
      .map((change) => change.path)
      .toList();
  if (dartFiles.isEmpty) {
    print('No staged Dart files to format.');
    return;
  }

  final temporary = await Directory.systemTemp.createTemp(
    'totem-staged-format-',
  );
  try {
    final packageConfig = File('.dart_tool/package_config.json');
    if (packageConfig.existsSync()) {
      final destination = File(
        '${temporary.path}/.dart_tool/package_config.json',
      )..createSync(recursive: true);
      await packageConfig.copy(destination.path);
    }
    for (final path in dartFiles) {
      final file = File('${temporary.path}${Platform.pathSeparator}$path')
        ..createSync(recursive: true);
      final stagedSource = await git.indexFile(path);
      await file.writeAsBytes(stagedSource);
      await _copyIndexConfiguration(path, temporary, git);
      if (!await isDartFormatted(file, stagedSource)) {
        throw ProcessException(
          'dart',
          ['format', '--output=json', path],
          'Staged file is not formatted: $path',
          1,
        );
      }
    }
    print('Checked formatting for ${dartFiles.length} staged Dart file(s).');
  } finally {
    await temporary.delete(recursive: true);
  }
}

/// Returns whether [source] exactly matches Dart's non-mutating formatter
/// output for [file]. JSON avoids the status line included in `--output=show`.
Future<bool> isDartFormatted(File file, List<int> source) async {
  final result = await Process.run('dart', [
    'format',
    '--output=json',
    file.path,
  ]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw ProcessException(
      'dart',
      ['format', '--output=json', file.path],
      'Could not format file: ${file.path}',
      result.exitCode,
    );
  }
  final formatted = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  return _sameBytes(source, utf8.encode(formatted['source'] as String));
}

Future<void> checkWorkingTreeFormatting(Iterable<String> paths) async {
  final files = [
    for (final path in paths)
      if (path.endsWith('.dart') &&
          !_isGeneratedOrCachePath(path) &&
          File(path).existsSync())
        File(path),
  ];
  if (files.isEmpty) return;

  final sources = {
    for (final file in files) file.path: await file.readAsBytes(),
  };
  final result = await Process.run('dart', [
    'format',
    '--output=json',
    ...files.map((file) => file.path),
  ]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw ProcessException(
      'dart',
      ['format', '--output=json', ...files.map((file) => file.path)],
      'Could not format files',
      result.exitCode,
    );
  }

  final formatted = const LineSplitter()
      .convert(result.stdout as String)
      .where((line) => line.isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .toList();
  if (formatted.length != files.length) {
    throw StateError('Dart formatter returned an unexpected number of files');
  }
  for (var index = 0; index < files.length; index++) {
    final source = utf8.encode(formatted[index]['source'] as String);
    if (!_sameBytes(sources[files[index].path]!, source)) {
      throw ProcessException(
        'dart',
        ['format', '--output=json', files[index].path],
        'File is not formatted: ${files[index].path}',
        1,
      );
    }
  }
}

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

Future<void> _copyIndexConfiguration(
  String path,
  Directory temporary,
  GitClient git,
) async {
  final parts = path.split('/');
  final candidates = <String>{'pubspec.yaml', 'analysis_options.yaml'};
  for (var index = 1; index < parts.length; index++) {
    final prefix = parts.take(index).join('/');
    candidates
      ..add('$prefix/pubspec.yaml')
      ..add('$prefix/analysis_options.yaml');
  }
  for (final config in candidates) {
    try {
      final destination = File(
        '${temporary.path}${Platform.pathSeparator}$config',
      )..createSync(recursive: true);
      await destination.writeAsBytes(await git.indexFile(config));
    } on ProcessException {
      // Not every source directory owns both configuration files.
    }
  }
}

Future<void> runPreCommit() async {
  final git = GitClient();
  final changes = await git.stagedChanges();
  await checkStagedFormatting(changes, git);

  final sourceFiles = changes
      .map((change) => change.path)
      .where(_isDefaultLintSource)
      .toList();
  if (sourceFiles.isEmpty) return;

  await runCommands([
    CheckCommand('dart', [
      'scripts/check_media_boundary.dart',
      '--staged',
      ...sourceFiles,
    ]),
  ], const ProcessCommandRunner());
  await _runStagedInterpolationCheck(sourceFiles, git);
}

bool _isDefaultLintSource(String path) =>
    path.endsWith('.dart') &&
    (path.startsWith('packages/totem_core/lib/') ||
        path.startsWith('packages/totem_app/lib/') ||
        path.startsWith('packages/totem_web/lib/'));

Future<void> _runStagedInterpolationCheck(
  List<String> sourceFiles,
  GitClient git,
) async {
  final temporary = await Directory.systemTemp.createTemp(
    'totem-staged-analysis-',
  );
  try {
    await git.checkoutIndex(temporary.path);
    final packageConfig = File('.dart_tool/package_config.json');
    if (packageConfig.existsSync()) {
      await _copyDirectory(
        Directory('.dart_tool'),
        Directory('${temporary.path}/.dart_tool'),
      );
    }
    await runCommands([
      CheckCommand('dart', [
        'scripts/check_omittable_interpolation.dart',
        '--workspace=${temporary.path}',
        '--files',
        ...sourceFiles,
      ]),
    ], const ProcessCommandRunner());
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(
    recursive: false,
    followLinks: false,
  )) {
    final name = entity.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final target = '${destination.path}${Platform.pathSeparator}$name';
    if (entity is File) {
      await entity.copy(target);
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory(target));
    }
  }
}

Future<void> runPrePush(
  String input, {
  GitClient? gitClient,
  Workspace? workspace,
  CommandRunner? commandRunner,
  bool? workspaceResolved,
}) async {
  final git = gitClient ?? const GitClient();
  final updates = parseRefUpdates(input);
  final changes = <GitChange>[];
  var reliable = true;

  for (final update in updates) {
    if (update.isDeletion) continue;
    String? base;
    if (!update.isNewBranch && await git.objectExists(update.remoteSha)) {
      base = update.remoteSha;
    } else if (update.isNewBranch) {
      final defaultBranch = await git.defaultRemoteBranch();
      if (defaultBranch != null) {
        base = await git.mergeBase(defaultBranch, update.localSha);
      }
    }
    if (base == null) {
      reliable = false;
      continue;
    }
    changes.addAll(await git.changesBetween(base, update.localSha));
  }

  final currentWorkspace = workspace ?? await loadWorkspace();
  final plan = planValidation(currentWorkspace, changes);
  if (!reliable) plan.requireFullValidation();
  if (!plan.hasWork) {
    print('No source or validation-affecting files in this push.');
    return;
  }

  print(_describePlan(plan));
  await runCommands(
    prePushCommands(
      plan,
      workspaceResolved:
          workspaceResolved ?? hasWorkspaceResolution(currentWorkspace),
    ),
    commandRunner ?? const ProcessCommandRunner(),
  );
}

String _describePlan(ValidationPlan plan) {
  if (plan.full) return 'Running comprehensive validation.';
  final analyzed = plan.analyzePackages.isEmpty
      ? 'none'
      : plan.analyzePackages.join(', ');
  final tested = plan.testPackages.isEmpty
      ? 'none'
      : plan.testPackages.join(', ');
  return 'Analyzing: $analyzed; testing: $tested.';
}

Future<void> main(List<String> args) async {
  if (args.length != 1 || !{'pre-commit', 'pre-push'}.contains(args.single)) {
    stderr.writeln('Usage: dart scripts/git_checks.dart <pre-commit|pre-push>');
    exitCode = 64;
    return;
  }
  try {
    if (args.single == 'pre-commit') {
      await runPreCommit();
    } else {
      await runPrePush(await stdin.transform(utf8.decoder).join());
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln(error);
    if (error is! ProcessException) stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
