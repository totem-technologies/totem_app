import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  final maxAttempts = int.tryParse(Platform.environment['MAX_ATTEMPTS'] ?? '3');
  if (maxAttempts == null || maxAttempts < 1) {
    stderr.writeln('MAX_ATTEMPTS must be a positive integer.');
    exitCode = 2;
    return;
  }
  if (args.isEmpty) {
    stderr.writeln('Usage: dart retry_flutter_build.dart <command> [args...]');
    exitCode = 2;
    return;
  }

  final repoRoot = File.fromUri(Platform.script).parent.parent.parent;
  final scratch = Directory('${repoRoot.path}${Platform.pathSeparator}scratch');
  await scratch.create(recursive: true);
  final temp = await scratch.createTemp('flutter-build.');
  final log = File('${temp.path}${Platform.pathSeparator}build.log');
  try {
    var status = 1;
    var reason = '';
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final process = await Process.start(args.first, args.skip(1).toList());
      final sink = log.openWrite(mode: FileMode.writeOnly);
      Future<void> copy(Stream<List<int>> stream) async {
        await for (final chunk in stream) {
          stdout.add(chunk);
          sink.add(chunk);
        }
      }

      await Future.wait([copy(process.stdout), copy(process.stderr)]);
      await sink.close();
      status = await process.exitCode;
      if (status == 0) return;

      final output = await log.readAsString();
      if (output.contains('Could not resolve package dependencies')) {
        reason = 'Swift package resolution';
      } else if (output.contains(
            'Failed to install the following SDK components',
          ) &&
          RegExp(r'cmake;[0-9]').hasMatch(output)) {
        reason = 'CMake installation';
      } else {
        exitCode = status;
        return;
      }

      if (attempt < maxAttempts) {
        stderr.writeln(
          '$reason failed (attempt $attempt/$maxAttempts); retrying in 15s...',
        );
        await Future<void>.delayed(const Duration(seconds: 15));
      }
    }

    stderr.writeln('$reason still failing after $maxAttempts attempts.');
    exitCode = status;
  } finally {
    await temp.delete(recursive: true);
  }
}
