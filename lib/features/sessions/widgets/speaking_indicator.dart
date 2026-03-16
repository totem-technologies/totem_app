import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_app/shared/totem_icons.dart';

class SpeakingIndicatorAudioTrack extends StatelessWidget {
  const SpeakingIndicatorAudioTrack({
    required this.audioTrack,
    this.participant,
    this.foregroundColor = Colors.white,
    this.barCount = 3,
    super.key,
  });

  final AudioTrack? audioTrack;
  final Participant? participant;

  final Color? foregroundColor;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    if (audioTrack != null &&
        !audioTrack!.muted /* && audioTrack!.subscribed */ ) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RepaintBoundary(
            child: SoundWaveformWidget(
              audioTrack: audioTrack,
              participant: participant,
              options: AudioVisualizerWidgetOptions(
                color: foregroundColor,
                barCount: barCount,
                barMinOpacity: 0.8,
                spacing: 3,
                minHeight: constraints.maxHeight * 0.2,
                maxHeight: constraints.maxHeight,
              ),
            ),
          );
        },
      );
    } else {
      return TotemIcon(
        TotemIcons.microphoneOff,
        size: 20,
        color: foregroundColor,
      );
    }
  }
}

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
  EventsListener<ParticipantEvent>? _participantListener;
  EventsListener<TrackEvent>? _trackListener;

  TrackPublication<Track>? get audioTrack {
    if (widget.participant is RemoteParticipant) {
      return widget.participant.getTrackPublicationBySource(
        TrackSource.microphone,
      );
    } else {
      return widget.participant.audioTrackPublications
          .where((t) => t.track != null && t.track!.isActive && !t.track!.muted)
          .firstOrNull;
    }
  }

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
    _participantListener?.dispose();
    _participantListener = widget.participant.createListener();
    _participantListener!
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted)
      ..on<ParticipantEvent>(_onParticipantEvent);

    _trackListener?.dispose();
    _trackListener = null;
    if (audioTrack?.track != null) {
      _trackListener = audioTrack!.track!.createListener();
      _trackListener!.listen(_onTrackEvent);
    }
  }

  void _onTrackMuted(TrackMutedEvent event) {
    if (!mounted) return;
    if (event.publication.source == TrackSource.microphone) setState(() {});
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    if (!mounted) return;
    if (event.publication.source == TrackSource.microphone) setState(() {});
  }

  void _onTrackEvent(TrackEvent event) {
    if (!mounted) return;
    setState(() {});
  }

  void _onParticipantEvent(ParticipantEvent event) {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _participantListener?.dispose();
    _trackListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpeakingIndicatorAudioTrack(
      audioTrack: audioTrack?.track as AudioTrack?,
      participant: widget.participant,
      foregroundColor: widget.foregroundColor,
      barCount: widget.barCount,
    );
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
