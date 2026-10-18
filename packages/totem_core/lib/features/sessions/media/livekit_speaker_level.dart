import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_selector.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/speech_level.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Level bars for a participant's microphone, driven by the audio levels the
/// LiveKit server reports, so no audio is analysed on this device. Rebuilds
/// only when the microphone state or the level changes, so a quiet room
/// costs no frames.
class LiveKitSpeakerLevel extends StatelessWidget {
  const new({
    required this.participant,
    required this.changes,
    required this.meter,
    required this.color,
    required this.iconSize,
    super.key,
  });

  /// Looks up the participant on every change, so the bars follow them
  /// across a rejoin.
  final Participant? Function() participant;

  /// Emits whenever a participant's media or speaking level may have
  /// changed.
  final Stream<void> changes;

  /// Scales this participant's levels to how loud they have recently been.
  final SpeechLevelMeter meter;

  final Color color;
  final double iconSize;

  /// Feeds [meter], so it runs once per change for every mounted tile. That
  /// is safe because the meter depends on elapsed time, not on how often it
  /// is read.
  ({bool microphoneOn, double level}) _read() {
    final participant = this.participant();
    final microphoneOn = participant != null && isMicrophoneOn(participant);
    final level = microphoneOn && participant.isSpeaking
        ? meter.level(amplitudeToDb(participant.audioLevel))
        : 0.0;
    return (microphoneOn: microphoneOn, level: level);
  }

  @override
  Widget build(BuildContext context) {
    return LiveKitSelector(
      changes: changes,
      read: _read,
      builder: (context, reading) {
        if (!reading.microphoneOn) {
          return TotemIcon(
            TotemIcons.microphoneOff,
            size: iconSize,
            color: color,
          );
        }
        return LevelBars.fromLevel(reading.level, barCount: 3, color: color);
      },
    );
  }
}
