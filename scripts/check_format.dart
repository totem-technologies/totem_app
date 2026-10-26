// Compatibility entry point for staged, non-mutating formatting validation.

import 'git_checks.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    const git = GitClient();
    await checkStagedFormatting(await git.stagedChanges(), git);
    return;
  }
  if (args.first == '--files') {
    await checkWorkingTreeFormatting(args.skip(1));
    return;
  }
  throw ArgumentError('Usage: [--files <path...>]');
}
