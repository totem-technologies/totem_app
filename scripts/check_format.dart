import 'dart:io';

void main(List<String> args) async {
  // Get list of staged .dart files
  final gitResult = await Process.run(
    'git',
    ['diff', '--cached', '--name-only', '--diff-filter=ACMR'],
  );

  if (gitResult.exitCode != 0) {
    print('Error: Failed to get staged files from git');
    exit(1);
  }

  // Parse and filter for .dart files
  final stagedFiles = gitResult.stdout
      .toString()
      .split('\n')
      .where(
        (file) =>
            file.isNotEmpty &&
            file.endsWith('.dart') &&
            File(file).existsSync(),
      )
      .toList();

  if (stagedFiles.isEmpty) {
    print('No .dart files to check');
    exit(0);
  }

  // Run dart format check on the file
  final formatResult = await Process.run(
    'dart',
    ['format', '--set-exit-if-changed', ...stagedFiles],
  );

  if (formatResult.exitCode != 0) {
    print('❌ Code formatting issues detected in staged files!');
    print('Please stage changes and commit again.');
    print('');
    exit(1);
  } else {
    print('✅ Code formatting check passed');
    exit(0);
  }
}
