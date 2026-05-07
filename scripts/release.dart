import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

void main(List<String> args) {
  try {
    _runRelease();
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

void _runRelease() {
  _ensureInGitRepo();
  _ensureOnMainBranch();
  _fetchOriginMainAndTags();
  _ensureWorkingTreeClean();
  _ensureLocalMainUpToDate();

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw Exception('pubspec.yaml not found in current directory.');
  }

  final content = pubspec.readAsStringSync();
  final parsed = _Version.fromPubspec(content);
  if (parsed == null) {
    throw Exception(
      "Could not find a valid 'version: x.y.z(+build)' line in pubspec.yaml.",
    );
  }

  final current = parsed;
  final defaultSuggestion = _Version(
    major: current.major,
    minor: current.minor,
    patch: current.patch + 1,
    build: (current.build ?? 0) + 1,
  );

  stdout
    ..writeln('[release] Current version: ${current.asString()}')
    ..write(
      '[release] Enter new version [default ${defaultSuggestion.asString()}]. '
      'If you omit +build, it increments the build number: ',
    );

  final input = stdin.readLineSync()?.trim() ?? '';
  final chosen = _parseUserVersionInput(input, current, defaultSuggestion);

  // Ensure tag uniqueness by bumping build until free
  final unique = _ensureUniqueTag(chosen);

  if (unique != chosen) {
    stdout.writeln(
      '[release] Tag ${_tagFor(chosen)} already existed for requested version; '
      'bumped build to ${unique.asString()} to ensure uniqueness.',
    );
  }

  if (unique == current) {
    throw Exception(
      'Proposed version is identical to current version '
      '(${current.asString()}). Nothing to do.',
    );
  }

  // Update pubspec.yaml
  final updated = _Version.replaceInPubspec(content, unique);
  if (updated == content) {
    throw Exception(
      'Failed to update pubspec.yaml with new version (${unique.asString()}).',
    );
  }

  stdout.writeln(
    '[release] Updating pubspec.yaml -> version: ${unique.asString()}',
  );
  pubspec.writeAsStringSync(updated);

  // Commit and tag
  _runGit(['add', 'pubspec.yaml']);
  _runGit(['commit', '-m', 'chore(release): v${unique.asString()}']);

  final tag = _tagFor(unique);
  _runGit(['tag', '-a', tag, '-m', 'Release $tag']);

  // Push main and tag
  stdout.writeln('[release] Pushing to origin...');
  _runGit(['push', 'origin', 'main']);
  _runGit(['push', 'origin', tag]);

  stdout.writeln('[release] Done. Created and pushed $tag');
}

void _ensureInGitRepo() {
  final res = _runGit(['rev-parse', '--is-inside-work-tree'], check: false);
  if (res.exitCode != 0 || res.stdout.toString().trim() != 'true') {
    throw Exception('Not inside a git repository.');
  }
}

void _ensureOnMainBranch() {
  final res = _runGit(['rev-parse', '--abbrev-ref', 'HEAD']);
  final branch = res.stdout.toString().trim();
  if (branch != 'main') {
    throw Exception("You must run releases from 'main' (current: $branch).");
  }
}

void _fetchOriginMainAndTags() {
  // Best effort fetch to ensure tag uniqueness and
  // up-to-date checks are correct.
  _runGit(['fetch', 'origin', 'main', '--tags'], check: false);
}

void _ensureWorkingTreeClean() {
  final res = _runGit(['status', '--porcelain']);
  final status = res.stdout.toString().trim();
  if (status.isNotEmpty) {
    throw Exception('Working tree is dirty. Commit or stash changes first.');
  }
}

void _ensureLocalMainUpToDate() {
  String? local;
  String? remote;

  {
    final r = _runGit(['rev-parse', 'HEAD'], check: false);
    if (r.exitCode == 0) {
      local = r.stdout.toString().trim();
    }
  }
  {
    final r = _runGit(['rev-parse', 'origin/main'], check: false);
    if (r.exitCode == 0) {
      remote = r.stdout.toString().trim();
    }
  }

  if (local == null) {
    throw Exception('Unable to determine local HEAD.');
  }
  if (remote == null) {
    throw Exception(
      "Unable to determine 'origin/main'. Ensure 'origin' remote exists and has 'main'.",
    );
  }
  if (local != remote) {
    throw Exception(
      'Local main is not up-to-date with origin/main. Pull/rebase first.',
    );
  }
}

@immutable
class _Version {
  const _Version({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });
  final int major;
  final int minor;
  final int patch;
  final int? build;

  String asString() {
    final b = build ?? 0;
    return '$major.$minor.$patch+$b';
  }

  static final RegExp _lineRe = RegExp(
    r'^\s*version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+([0-9]+))?\s*$',
    multiLine: true,
  );

  static _Version? fromPubspec(String content) {
    final m = _lineRe.firstMatch(content);
    if (m == null) return null;
    final major = int.parse(m.group(1)!);
    final minor = int.parse(m.group(2)!);
    final patch = int.parse(m.group(3)!);
    final build = (m.group(4) != null) ? int.parse(m.group(4)!) : null;
    return _Version(major: major, minor: minor, patch: patch, build: build);
    // Note: asString() will always include +build (defaulting to +0)
  }

  static String replaceInPubspec(String content, _Version v) {
    return content.replaceFirstMapped(
      _lineRe,
      (m) => 'version: ${v.asString()}',
    );
  }

  _Version copyWith({int? major, int? minor, int? patch, int? build}) {
    return _Version(
      major: major ?? this.major,
      minor: minor ?? this.minor,
      patch: patch ?? this.patch,
      build: build ?? this.build,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _Version &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        (other.build ?? 0) == (build ?? 0);
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build ?? 0);
}

_Version _parseUserVersionInput(
  String input,
  _Version current,
  _Version defaultSuggestion,
) {
  if (input.isEmpty) return defaultSuggestion;

  final full = RegExp(r'^\s*([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)\s*$');
  final base = RegExp(r'^\s*([0-9]+)\.([0-9]+)\.([0-9]+)\s*$');

  final mFull = full.firstMatch(input);
  if (mFull != null) {
    return _Version(
      major: int.parse(mFull.group(1)!),
      minor: int.parse(mFull.group(2)!),
      patch: int.parse(mFull.group(3)!),
      build: int.parse(mFull.group(4)!),
    );
  }

  final mBase = base.firstMatch(input);
  if (mBase != null) {
    // If user omits +build, default to current build + 1
    return _Version(
      major: int.parse(mBase.group(1)!),
      minor: int.parse(mBase.group(2)!),
      patch: int.parse(mBase.group(3)!),
      build: (current.build ?? 0) + 1,
    );
  }

  throw Exception("Invalid version input. Expected 'x.y.z' or 'x.y.z+build'.");
}

_Version _ensureUniqueTag(_Version v) {
  var candidate = v;
  while (_tagExists(_tagFor(candidate))) {
    final nextBuild = (candidate.build ?? 0) + 1;
    candidate = candidate.copyWith(build: nextBuild);
  }
  return candidate;
}

bool _tagExists(String tag) {
  final res = _runGit([
    'rev-parse',
    '-q',
    '--verify',
    'refs/tags/$tag',
  ], check: false);
  return res.exitCode == 0;
}

String _tagFor(_Version v) => 'v${v.asString()}';

ProcessResult _runGit(List<String> args, {bool check = true}) {
  final res = Process.runSync('git', args, runInShell: true);
  if (check && res.exitCode != 0) {
    final cmd = 'git ${args.join(' ')}';
    final out =
        (res.stdout is String
                ? res.stdout as String
                : utf8.decode(res.stdout as List<int>))
            .trim();
    final err =
        (res.stderr is String
                ? res.stderr as String
                : utf8.decode(res.stderr as List<int>))
            .trim();
    throw Exception('Command failed ($cmd): ${err.isNotEmpty ? err : out}');
  }
  return res;
}
