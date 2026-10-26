import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../git_checks.dart';

void main() {
  final workspace = Workspace([
    const WorkspacePackage(
      name: 'totem_core',
      path: 'packages/totem_core',
      localDependencies: {},
    ),
    const WorkspacePackage(
      name: 'totem_app',
      path: 'packages/totem_app',
      localDependencies: {'totem_core'},
    ),
    const WorkspacePackage(
      name: 'totem_web',
      path: 'packages/totem_web',
      localDependencies: {'totem_core'},
    ),
    const WorkspacePackage(
      name: 'totem_benchmark',
      path: 'packages/totem_benchmark',
      localDependencies: {'totem_core'},
    ),
    const WorkspacePackage(
      name: 'totem_widgetbook',
      path: 'packages/totem_widgetbook',
      localDependencies: {'totem_core'},
    ),
  ]);

  GitChange changed(String path, [ChangeKind kind = ChangeKind.modified]) =>
      GitChange(kind, path);

  group('workspace graph', () {
    test('derives local path dependents from workspace pubspecs', () {
      final parsed = Workspace.fromPubspecs({
        'pubspec.yaml': '''
name: root
workspace:
  - packages/core
  - packages/app
''',
        'packages/core/pubspec.yaml': 'name: core\n',
        'packages/app/pubspec.yaml': '''
name: app
dependencies:
  core:
    path: ../core
''',
      });

      check(parsed.dependentsOf('core')).deepEquals({'app'});
    });
  });

  group('change classification', () {
    test('only one staged Dart file selects its owning package', () {
      final plan = planValidation(workspace, [
        changed('packages/totem_app/lib/app.dart'),
      ]);

      check(plan.full).isFalse();
      check(plan.analyzePackages).deepEquals({'totem_app'});
      check(plan.testPackages).deepEquals({'totem_app'});
      check(plan.sourceFiles).deepEquals({'packages/totem_app/lib/app.dart'});
      check(plan.runMediaCheck).isTrue();
      check(plan.runInterpolationCheck).isTrue();
    });

    test('documentation-only changes do no validation work', () {
      final plan = planValidation(workspace, [changed('docs/guide.md')]);

      check(plan.hasWork).isFalse();
    });

    test('generated output and package caches do no validation work', () {
      final plan = planValidation(workspace, [
        changed('packages/totem_app/build/generated.dart'),
        changed('packages/totem_core/.dart_tool/cache.dart'),
        changed('.pub-cache/pkg/example.dart'),
      ]);

      check(plan.hasWork).isFalse();
    });

    test('web changes validate only web', () {
      final plan = planValidation(workspace, [
        changed('packages/totem_web/lib/main.dart'),
      ]);

      check(plan.analyzePackages).deepEquals({'totem_web'});
      check(plan.testPackages).deepEquals({'totem_web'});
    });

    test('core changes analyze dependents but test only core', () {
      final plan = planValidation(workspace, [
        changed('packages/totem_core/lib/core.dart'),
      ]);

      check(plan.analyzePackages).deepEquals({
        'totem_core',
        'totem_app',
        'totem_web',
        'totem_benchmark',
        'totem_widgetbook',
      });
      check(plan.testPackages).deepEquals({'totem_core'});
    });

    test('multiple packages have a union of direct test suites', () {
      final plan = planValidation(workspace, [
        changed('packages/totem_core/lib/core.dart'),
        changed('packages/totem_web/lib/main.dart'),
      ]);

      check(plan.testPackages).deepEquals({'totem_core', 'totem_web'});
      check(plan.analyzePackages).contains('totem_web');
      check(plan.analyzePackages).contains('totem_app');
    });

    test('dependency manifests require comprehensive validation', () {
      final rootPlan = planValidation(workspace, [changed('pubspec.lock')]);
      final packagePlan = planValidation(workspace, [
        changed('packages/totem_app/pubspec.yaml'),
      ]);

      check(rootPlan.full).isTrue();
      check(rootPlan.needsPubGet).isTrue();
      check(packagePlan.full).isTrue();
      check(packagePlan.needsPubGet).isTrue();
    });

    test('validation scripts run their script tests', () {
      final plan = planValidation(workspace, [
        changed('scripts/check_omittable_interpolation.dart'),
      ]);

      check(plan.runScriptTests).isTrue();
      check(plan.full).isFalse();
    });

    test('benchmark scripts run their Node test without Flutter packages', () {
      final plan = planValidation(workspace, [
        changed('scripts/benchmark/metrics.mjs'),
      ]);
      final commands = prePushCommands(plan, workspaceResolved: true);

      check(commands).length.equals(1);
      check(commands.single.executable).equals('node');
    });

    test(
      'added, deleted, and renamed package files remain package changes',
      () {
        final plan = planValidation(workspace, [
          changed('packages/totem_app/lib/new.dart', ChangeKind.added),
          changed('packages/totem_app/lib/old.dart', ChangeKind.deleted),
          const GitChange(
            ChangeKind.renamed,
            'packages/totem_app/lib/renamed.dart',
            oldPath: 'packages/totem_app/lib/previous.dart',
          ),
        ]);

        check(plan.analyzePackages).deepEquals({'totem_app'});
        check(plan.testPackages).deepEquals({'totem_app'});
      },
    );

    test(
      'shared configuration falls back without unnecessary dependency resolution',
      () {
        final plan = planValidation(workspace, [changed('.githooks/pre-push')]);

        check(plan.full).isTrue();
        check(plan.needsPubGet).isFalse();
      },
    );

    test('unfamiliar files fall back to comprehensive validation', () {
      final plan = planValidation(workspace, [changed('ci-input.json')]);

      check(plan.full).isTrue();
    });
  });

  group('git protocol parsing', () {
    test('parses added, deleted, and renamed NUL-delimited paths', () {
      final changes = parseNameStatus(
        'A\u0000packages/totem_app/lib/new.dart\u0000'
        'D\u0000packages/totem_web/lib/old.dart\u0000'
        'R100\u0000before.dart\u0000after.dart\u0000',
      );

      check(changes).length.equals(3);
      check(changes[0].kind).equals(ChangeKind.added);
      check(changes[1].kind).equals(ChangeKind.deleted);
      check(changes[2].kind).equals(ChangeKind.renamed);
      check(changes[2].oldPath).equals('before.dart');
      check(changes[2].path).equals('after.dart');
    });

    test('parses new branches, deletions, and multiple pushed refs', () {
      const zero = '0000000000000000000000000000000000000000';
      final updates = parseRefUpdates(
        'refs/heads/new abc refs/heads/new $zero\n'
        '$zero $zero refs/heads/deleted abc\n',
      );

      check(updates).length.equals(2);
      check(updates.first.isNewBranch).isTrue();
      check(updates.last.isDeletion).isTrue();
    });
  });

  group('command execution', () {
    test('missing workspace resolution requests one dependency resolution', () {
      final plan = planValidation(workspace, [
        changed('packages/totem_app/lib/app.dart'),
      ]);
      final commands = prePushCommands(plan, workspaceResolved: false);

      check(commands.first.executable).equals('flutter');
      check(commands.first.arguments).deepEquals(['pub', 'get']);
      check(
        commands.where((command) => command.executable == 'flutter'),
      ).length.equals(2);
    });

    test('a failed command blocks remaining validation', () async {
      final runner = _RecordingRunner(failAt: 1);
      var failed = false;

      try {
        await runCommands(const [
          CheckCommand('first', []),
          CheckCommand('second', []),
        ], runner);
      } on ProcessException {
        failed = true;
      }

      check(failed).isTrue();
      check(runner.commands).length.equals(1);
    });

    test('multiple refs combine their affected package commands', () async {
      final runner = _RecordingRunner();
      await runPrePush(
        'refs/heads/app app refs/heads/app remote-app\n'
        'refs/heads/web web refs/heads/web remote-web\n',
        gitClient: _FakeGitClient({
          'app': [
            GitChange(ChangeKind.modified, 'packages/totem_app/lib/app.dart'),
          ],
          'web': [
            GitChange(ChangeKind.modified, 'packages/totem_web/lib/main.dart'),
          ],
        }),
        workspace: workspace,
        commandRunner: runner,
        workspaceResolved: true,
      );

      check(
        runner.commands.where((command) => command.executable == 'flutter'),
      ).length.equals(2);
      check(
        runner.commands.where((command) => command.executable == 'make'),
      ).length.equals(2);
    });

    test(
      'an unavailable comparison base uses comprehensive validation',
      () async {
        final runner = _RecordingRunner();
        await runPrePush(
          'refs/heads/new new refs/heads/new '
          '0000000000000000000000000000000000000000\n',
          gitClient: _FakeGitClient(const {}, defaultBranch: null),
          workspace: workspace,
          commandRunner: runner,
          workspaceResolved: true,
        );

        check(runner.commands).length.equals(3);
        check(runner.commands.first.arguments).deepEquals(['format-check']);
      },
    );

    test(
      'successful commands return without changing the command list',
      () async {
        final runner = _RecordingRunner();
        const commands = [
          CheckCommand('check', ['one']),
        ];

        await runCommands(commands, runner);

        check(runner.commands).length.equals(1);
        check(runner.commands.single.arguments).deepEquals(['one']);
      },
    );
  });
}

class _FakeGitClient extends GitClient {
  _FakeGitClient(this.changesByTarget, {this.defaultBranch = 'origin/main'});

  final Map<String, List<GitChange>> changesByTarget;
  final String? defaultBranch;

  @override
  Future<bool> objectExists(String sha) async => true;

  @override
  Future<List<GitChange>> changesBetween(String base, String target) async =>
      changesByTarget[target] ?? const [];

  @override
  Future<String?> defaultRemoteBranch() async => defaultBranch;

  @override
  Future<String?> mergeBase(String first, String second) async => first;
}

class _RecordingRunner implements CommandRunner {
  _RecordingRunner({this.failAt});

  final int? failAt;
  final commands = <CheckCommand>[];

  @override
  Future<int> run(CheckCommand command) async {
    commands.add(command);
    return commands.length == failAt ? 1 : 0;
  }
}
