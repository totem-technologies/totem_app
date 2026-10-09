import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Audio level bars for a LiveKit participant's microphone, or for a
/// standalone [audioTrack] such as the pre-join preview. Shows a
/// microphone-off icon while the track is muted or missing.
class LiveKitMicrophoneLevel extends StatefulWidget {
  const LiveKitMicrophoneLevel({
    required this.foregroundColor,
    required this.barCount,
    this.audioTrack,
    this.participant,
    this.iconSize = 20,
    super.key,
  });

  final AudioTrack? audioTrack;
  final Participant? participant;
  final Color? foregroundColor;
  final int barCount;
  final double iconSize;

  @override
  State<LiveKitMicrophoneLevel> createState() => _LiveKitMicrophoneLevelState();
}

class _LiveKitMicrophoneLevelState extends State<LiveKitMicrophoneLevel> {
  EventsListener<ParticipantEvent>? _participantListener;
  EventsListener<TrackEvent>? _trackListener;

  TrackPublication<Track>? get _microphonePublication {
    final participant = widget.participant;

    if (participant is RemoteParticipant) {
      return participant.getTrackPublicationBySource(TrackSource.microphone);
    } else {
      return participant?.audioTrackPublications
          .where((t) => t.track != null && isTrackLive(t))
          .firstOrNull;
    }
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void didUpdateWidget(covariant LiveKitMicrophoneLevel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant?.sid != widget.participant?.sid ||
        oldWidget.audioTrack != widget.audioTrack) {
      _setupListeners();
    }
  }

  AudioTrack? get _resolvedAudioTrack {
    final publicationTrack = _microphonePublication?.track;
    return widget.audioTrack ?? publicationTrack as AudioTrack?;
  }

  void _setupListeners() {
    _participantListener?.dispose();
    _participantListener = widget.participant?.createListener();
    _participantListener
      ?..on<TrackPublishedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<TrackUnpublishedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<TrackSubscribedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<TrackUnsubscribedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted);

    _trackListener?.dispose();
    _trackListener = null;
    final resolvedTrack = _resolvedAudioTrack;
    if (widget.participant == null && resolvedTrack != null) {
      _trackListener = resolvedTrack.createListener();
      _trackListener!.listen(_onTrackEvent);
    }
  }

  void _onMicrophonePublicationChanged(TrackPublication<Track> publication) {
    if (!mounted || publication.source != TrackSource.microphone) return;
    setState(() {});
  }

  void _onTrackMuted(TrackMutedEvent event) {
    _onMicrophonePublicationChanged(event.publication);
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    _onMicrophonePublicationChanged(event.publication);
  }

  void _onTrackEvent(TrackEvent event) {
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
      size: widget.iconSize,
      color: widget.foregroundColor,
    );
  }
}
