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
    return _SpeakingIndicatorCore(
      audioTrack: audioTrack,
      participant: participant,
      foregroundColor: foregroundColor,
      barCount: barCount,
    );
  }
}

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
    return _SpeakingIndicatorCore(
      participant: participant,
      foregroundColor: foregroundColor,
      barCount: barCount,
    );
  }
}

class _SpeakingIndicatorCore extends StatefulWidget {
  const _SpeakingIndicatorCore({
    required this.foregroundColor,
    required this.barCount,
    this.audioTrack,
    this.participant,
  });

  final AudioTrack? audioTrack;
  final Participant? participant;
  final Color? foregroundColor;
  final int barCount;

  @override
  State<_SpeakingIndicatorCore> createState() => _SpeakingIndicatorCoreState();
}

class _SpeakingIndicatorCoreState extends State<_SpeakingIndicatorCore> {
  EventsListener<ParticipantEvent>? _participantListener;
  EventsListener<TrackEvent>? _trackListener;

  TrackPublication<Track>? get audioTrack {
    final participant = widget.participant;

    if (participant is RemoteParticipant) {
      return participant.getTrackPublicationBySource(
        TrackSource.microphone,
      );
    } else {
      return participant?.audioTrackPublications
          .where((t) => t.track != null && t.track!.isActive && !t.track!.muted)
          .firstOrNull;
    }
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void didUpdateWidget(covariant _SpeakingIndicatorCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant?.sid != widget.participant?.sid ||
        oldWidget.audioTrack != widget.audioTrack) {
      _setupListeners();
    }
  }

  AudioTrack? get _resolvedAudioTrack {
    final publicationTrack = audioTrack?.track;
    return widget.audioTrack ?? publicationTrack as AudioTrack?;
  }

  void _setupListeners() {
    _participantListener?.dispose();
    _participantListener = widget.participant?.createListener();
    _participantListener
      ?..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted)
      ..on<ParticipantEvent>(_onParticipantEvent);

    _trackListener?.dispose();
    _trackListener = null;
    final resolvedTrack = _resolvedAudioTrack;
    if (resolvedTrack != null) {
      _trackListener = resolvedTrack.createListener();
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
    final resolvedAudioTrack = _resolvedAudioTrack;

    if (resolvedAudioTrack != null && !resolvedAudioTrack.muted) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RepaintBoundary(
            child: SoundWaveformWidget(
              audioTrack: resolvedAudioTrack,
              participant: widget.participant,
              options: AudioVisualizerWidgetOptions(
                color: widget.foregroundColor,
                barCount: widget.barCount,
                barMinOpacity: 0.8,
                spacing: 2.5,
                minHeight: constraints.maxHeight * 0.2,
                maxHeight: constraints.maxHeight,
              ),
            ),
          );
        },
      );
    }

    return TotemIcon(
      TotemIcons.microphoneOff,
      size: 20,
      color: widget.foregroundColor,
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
                    alignment: AlignmentDirectional.center,
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
        alignment: AlignmentDirectional.center,
        child: SpeakingIndicator(participant: participant),
      ),
    );
  }
}
