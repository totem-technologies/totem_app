import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_app/shared/totem_icons.dart';

class SpeakingIndicator extends StatelessWidget {
  const SpeakingIndicator({
    required this.participant,
    this.foregroundColor = Colors.white,
    this.barCount = 3,
    super.key,
  });

  final Participant participant;
  final Color foregroundColor;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final audioTracks = participant
        .getTrackPublications()
        .where((t) => t.kind == TrackType.AUDIO && t.track is AudioTrack)
        .toList();
    if (participant.isMuted || !participant.hasAudio || audioTracks.isEmpty) {
      return TotemIcon(
        TotemIcons.microphoneOff,
        size: 20,
        color: foregroundColor,
      );
    } else {
      return RepaintBoundary(
        child: SoundWaveformWidget(
          audioTrack: audioTracks.firstOrNull?.track as AudioTrack?,
          participant: participant,
          options: AudioVisualizerWidgetOptions(
            color: foregroundColor,
            barCount: barCount,
            barMinOpacity: 0.8,
            spacing: 3,
            minHeight: 4,
            maxHeight: 12,
          ),
        ),
      );
    }
  }
}

class SpeakingIndicatorOrEmoji extends StatelessWidget {
  const SpeakingIndicatorOrEmoji({required this.participant, super.key});

  final Participant participant;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final emojis = ref.watch(
          participantEmojisProvider(participant.identity),
        );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: emojis.isNotEmpty
              ? Container(
                  key: ValueKey(emojis.first),
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emojis.first,
                    style: const TextStyle(
                      fontSize: 10,
                      textBaseline: TextBaseline.ideographic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : child,
        );
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
        ),
        padding: const EdgeInsetsDirectional.all(2),
        alignment: Alignment.center,
        child: SpeakingIndicator(
          participant: participant,
        ),
      ),
    );
  }
}
