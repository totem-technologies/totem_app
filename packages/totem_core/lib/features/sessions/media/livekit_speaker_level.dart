import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';

/// A participant microphone indicator driven by samples from their subscribed
/// microphone track.
class LiveKitSpeakerLevel extends StatelessWidget {
  const LiveKitSpeakerLevel({
    required this.participant,
    required this.changes,
    required this.color,
    required this.iconSize,
    super.key,
  });

  /// Looks up the participant on every change, so the bars follow them
  /// across a rejoin.
  final Participant? Function() participant;

  /// Emits whenever the participant's microphone publication or track may
  /// have changed.
  final Stream<void> changes;

  final Color color;
  final double iconSize;

  TrackPublication<Track>? _publication() =>
      participant()?.getTrackPublicationBySource(TrackSource.microphone);

  bool _microphoneOn() {
    final participant = this.participant();
    final publication = _publication();
    return participant != null &&
        isMicrophoneOn(participant) &&
        !(publication?.muted ?? false);
  }

  AudioTrack? _track() {
    final track = _publication()?.track;
    return track is AudioTrack ? track : null;
  }

  @override
  Widget build(BuildContext context) => LiveKitMicrophoneLevel(
    track: _track,
    changes: changes,
    color: color,
    barCount: 5,
    microphoneOn: _microphoneOn,
    iconSize: iconSize,
  );
}
