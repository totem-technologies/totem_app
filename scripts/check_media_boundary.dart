// Checks that local capture is controlled only by the media adapters.
//
// LiveKit reads the microphone's mute policy from several places, and a soft
// unmute cannot recover a track that a hard mute stopped. Keeping every
// capture call inside lib/features/sessions/media/ keeps that policy in one
// place. The pre-join controller is exempt: it manages preview tracks before
// a room exists.

// OK to use print
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _allowedPaths = [
  'packages/totem_core/lib/features/sessions/media/',
  'packages/totem_core/lib/features/sessions/pre_join/pre_join_media_controller.dart',
];

// Migration baseline: these existing SDK consumers still need transport or
// capture-handle migration. Remove entries as their direct imports disappear.
// An exception applies to one existing file, never an orchestration directory.
const _existingSdkConsumers = {
  'controllers/core/session_state.dart',
  'controllers/core/join_media_owner.dart',
  'controllers/features/session_messaging_controller.dart',
  'pre_join/pre_join_flow_controller.dart',
  'pre_join/pre_join_media_controller.dart',
  'pre_join/pre_join_state.dart',
  'pre_join/pre_join_preview_card.dart',
  'admission/admission_transport.dart',
  'admission/session_admission_service.dart',
  'providers/session_scope_provider.dart',
  'screens/room_screen.dart',
  'screens/session_disconnected.dart',
};

List<String> _sdkViolations(String path, String source) {
  const root = 'packages/totem_core/lib/features/sessions/';
  if (!path.startsWith(root)) return const [];
  final relative = path.substring(root.length);
  if (relative.startsWith('media/') ||
      _existingSdkConsumers.contains(relative)) {
    return const [];
  }
  final parsed = parseString(content: source, throwIfDiagnostics: false);
  final violations = <String>[];
  for (final directive
      in parsed.unit.directives.whereType<NamespaceDirective>()) {
    final uris = [directive.uri, ...directive.configurations.map((c) => c.uri)];
    for (final uri in uris) {
      if (!(uri.stringValue?.startsWith('package:livekit_client/') ?? false))
        continue;
      final line = parsed.lineInfo.getLocation(uri.offset).lineNumber;
      violations.add(
        '$path:$line: keep LiveKit imports and exports behind the Sessions media adapters',
      );
    }
  }
  return violations;
}

final _forbidden = <RegExp, String>{
  // Formatting can break the chain after localParticipant.
  RegExp(r'localParticipant\s*\??\.set(Microphone|Camera)Enabled\('):
      'toggle capture through LocalMedia',
  RegExp(r'\b(publishAudioTrack|publishVideoTrack|unpublishAllTracks)\('):
      'publish or release tracks through LiveKitLocalMedia',
  RegExp(r'\bsetSourceEnabled\('): 'toggle capture through LocalMedia',
  RegExp(r'\bstopOnMute\b|\bstopAudioCaptureOnMute\b'):
      'leave the mute policy to LiveKitLocalMedia',
  RegExp(r'\bdefaultAudioCaptureOptions\b'):
      'set room capture defaults with LiveKitLocalMedia.applyCapturePolicy',
};

/// Returns one message per forbidden capture call in [files], keyed by path.
List<String> findViolations(Map<String, String> files) {
  final violations = <String>[];
  for (final MapEntry(key: path, value: source) in files.entries) {
    final normalizedPath = path.replaceAll(r'\', '/');
    violations.addAll(_sdkViolations(normalizedPath, source));
    if (_allowedPaths.any(normalizedPath.startsWith)) continue;
    final lines = source.split('\n');
    for (final MapEntry(key: pattern, value: advice) in _forbidden.entries) {
      for (final match in pattern.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        violations.add('$path:${line + 1}: $advice\n  ${lines[line].trim()}');
      }
    }
  }
  return violations;
}

Future<Map<String, String>> filesForCheck(List<String> args) async {
  if (args.isEmpty) {
    return {
      for (final package in Directory('packages').listSync())
        if (Directory('${package.path}/lib').existsSync())
          for (final entity in Directory(
            '${package.path}/lib',
          ).listSync(recursive: true, followLinks: false))
            if (entity is File &&
                entity.path.endsWith('.dart') &&
                !entity.path.endsWith('.g.dart'))
              entity.path: entity.readAsStringSync(),
    };
  }

  final staged = args.first == '--staged';
  final paths = args.skip(1);
  if (!staged && args.first != '--files') {
    throw ArgumentError('Usage: --files <path...> or --staged <path...>');
  }
  final files = <String, String>{};
  for (final path in paths) {
    if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
    if (staged) {
      final result = await Process.run('git', ['show', ':$path']);
      if (result.exitCode == 0) files[path] = result.stdout.toString();
    } else {
      final file = File(path);
      if (file.existsSync()) files[path] = await file.readAsString();
    }
  }
  return files;
}

Future<void> main(List<String> args) async {
  final violations = findViolations(await filesForCheck(args));
  if (violations.isEmpty) {
    print(
      '✅ Media capture and new Sessions SDK dependencies stay behind adapters',
    );
    return;
  }
  print('❌ Sessions media boundary violations:');
  violations.forEach(print);
  exit(1);
}
