import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/local_audio_bands.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer_bars.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Audio level bars measured on this device for a LiveKit participant's
/// microphone, or for a standalone [audioTrack] such as the pre-join preview.
/// Shows a microphone-off icon while the track is muted or missing.
///
/// Meant for the local microphone. On web the bars come from
/// [localAudioBands], which redraws only when the levels change; native
/// platforms use the SDK visualizer.
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
      ..on<LocalTrackPublishedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<LocalTrackUnpublishedEvent>(
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
      if (kIsWeb) {
        return _WebLevelBars(
          track: resolvedAudioTrack,
          barCount: widget.barCount,
          color: widget.foregroundColor,
        );
      }
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

class _WebLevelBars extends StatefulWidget {
  const _WebLevelBars({
    required this.track,
    required this.barCount,
    required this.color,
  });

  final AudioTrack track;
  final int barCount;
  final Color? color;

  @override
  State<_WebLevelBars> createState() => _WebLevelBarsState();
}

class _WebLevelBarsState extends State<_WebLevelBars> {
  StreamSubscription<List<double>>? _subscription;
  late List<double> _levels;

  void _listen() {
    unawaited(_subscription?.cancel());
    _levels = List.filled(widget.barCount, 0);
    _subscription = localAudioBands(
      widget.track,
      bandCount: widget.barCount,
    ).listen((levels) => setState(() => _levels = levels));
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _WebLevelBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track ||
        oldWidget.barCount != widget.barCount) {
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LevelBars(
      levels: _levels,
      color: widget.color ?? IconTheme.of(context).color ?? Colors.white,
    );
  }
}
