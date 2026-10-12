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

const _allowedPaths = [
  'packages/totem_core/lib/features/sessions/media/',
  'packages/totem_core/lib/features/sessions/pre_join/pre_join_media_controller.dart',
];

final _forbidden = <RegExp, String>{
  RegExp(r'localParticipant\??\.set(Microphone|Camera)Enabled\('):
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
    if (_allowedPaths.any(path.startsWith)) continue;
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      for (final MapEntry(key: pattern, value: advice) in _forbidden.entries) {
        if (pattern.hasMatch(lines[i])) {
          violations.add('$path:${i + 1}: $advice\n  ${lines[i].trim()}');
        }
      }
    }
  }
  return violations;
}

void main() {
  final files = <String, String>{
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

  final violations = findViolations(files);
  if (violations.isEmpty) {
    print('✅ Local capture stays behind the media adapters');
    return;
  }
  print('❌ Local capture calls outside lib/features/sessions/media/:');
  violations.forEach(print);
  exit(1);
}
