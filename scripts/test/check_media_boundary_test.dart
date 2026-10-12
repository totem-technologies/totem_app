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
