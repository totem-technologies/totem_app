import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_app/shared/totem_icons.dart';

class SpeakingIndicator extends StatefulWidget {
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
  State<SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<SpeakingIndicator> {
  EventsListener<ParticipantEvent>? _listener;

  @override
  void initState() {
    super.initState();
    setup();
  }

  @override
  void didUpdateWidget(covariant SpeakingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid) {
      setup();
    }
  }

  void setup() {
    _listener?.dispose();
    _listener = widget.participant.createListener();
    _listener!
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted);
  }

  void _onTrackMuted(TrackMutedEvent event) {
    if (!mounted) return;
    if (event.publication.source == TrackSource.microphone) {
      setState(() {});
    }
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    if (!mounted) return;
    if (event.publication.source == TrackSource.microphone) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioTrack = widget.participant.getTrackPublicationBySource(
      TrackSource.microphone,
    );
    if (audioTrack == null || !audioTrack.subscribed || audioTrack.muted) {
      return TotemIcon(
        TotemIcons.microphoneOff,
        size: 20,
        color: widget.foregroundColor,
      );
    } else {
      return RepaintBoundary(
        child: SoundWaveformWidget(
          audioTrack: audioTrack.track as AudioTrack?,
          participant: widget.participant,
          options: AudioVisualizerWidgetOptions(
            color: widget.foregroundColor,
            barCount: widget.barCount,
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
  const SpeakingIndicatorOrEmoji({
    required this.participant,
    this.backgroundColor = Colors.black54,
    super.key,
  });

  final Participant participant;
  final Color backgroundColor;

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
              ? MediaQuery.withNoTextScaling(
                  child: Container(
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
                  ),
                )
              : child,
        );
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        padding: const EdgeInsetsDirectional.all(2),
        alignment: Alignment.center,
        child: SpeakingIndicator(participant: participant),
      ),
    );
  }
}
