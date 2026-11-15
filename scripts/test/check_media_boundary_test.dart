import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../check_media_boundary.dart';

void main() {
  const screen = 'packages/totem_core/lib/features/sessions/screens/room.dart';

  test('rejects SDK imports and conditional exports in new domain files', () {
    final violations = findViolations({
      screen:
          "import 'package:livekit_client/livekit_client.dart' as sdk;\n"
          "export 'stub.dart' if (dart.library.js_interop) 'package:livekit_client/livekit_client.dart';",
    });
    check(violations).length.equals(2);
    check(violations.first).startsWith('$screen:1:');
    check(violations.last).startsWith('$screen:2:');
  });

  test('SDK names inside comments and strings do not violate the boundary', () {
    check(
      findViolations({
        screen:
            "// import 'package:livekit_client/livekit_client.dart';\nconst example = \"package:livekit_client/livekit_client.dart\";",
      }),
    ).isEmpty();
  });

  test('allows adapter SDK imports and the explicit migration baseline', () {
    const source = "import 'package:livekit_client/livekit_client.dart';";
    check(
      findViolations({
        'packages/totem_core/lib/features/sessions/media/livekit_room_media.dart':
            source,
        'packages/totem_core/lib/features/sessions/controllers/core/session_state.dart':
            source,
      }),
    ).isEmpty();
    check(
      findViolations({
        'packages/totem_core/lib/features/sessions/controllers/core/new_controller.dart':
            source,
      }),
    ).length.equals(1);
  });

  test('SessionController may no longer import the SDK', () {
    check(
      findViolations({
        'packages/totem_core/lib/features/sessions/controllers/core/session_controller.dart':
            "import 'package:livekit_client/livekit_client.dart';",
      }),
    ).length.equals(1);
  });

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
