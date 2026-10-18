import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../check_media_boundary.dart';

void main() {
  const screen = 'packages/totem_core/lib/features/sessions/screens/room.dart';

  test('flags capture calls outside the media adapters', () {
    final violations = findViolations({
      screen: '''
await room.localParticipant?.setMicrophoneEnabled(false);
await track.mute(stopOnMute: false);
''',
    });

    check(violations).length.equals(2);
    check(violations.first).startsWith('$screen:1:');
  });

  test('flags calls that formatting splits across lines', () {
    final violations = findViolations({
      screen: '''
await session.room.localParticipant
    ?.setMicrophoneEnabled(false);
''',
    });

    check(violations).length.equals(1);
    check(violations.single).startsWith('$screen:1:');
  });

  test('allows the media adapters on Windows paths too', () {
    final violations = findViolations({
      r'packages\totem_core\lib\features\sessions\media\livekit_local_media.dart':
          'await participant.publishAudioTrack(track);',
    });

    check(violations).isEmpty();
  });

  test('allows capture calls inside the media adapters', () {
    final violations = findViolations({
      'packages/totem_core/lib/features/sessions/media/livekit_local_media.dart':
          'await participant.publishAudioTrack(track);',
    });

    check(violations).isEmpty();
  });

  test('allows calls through the LocalMedia interface', () {
    final violations = findViolations({
      screen: 'await session.localMedia.setMicrophoneEnabled(true);',
    });

    check(violations).isEmpty();
  });
}
