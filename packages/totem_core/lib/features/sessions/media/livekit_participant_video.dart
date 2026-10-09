import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:material_ui/material_ui.dart';

@immutable
class _ParticipantVideoRenderState {
  const _ParticipantVideoRenderState({
    required this.publication,
    required this.track,
  });

  final TrackPublication<Track>? publication;
  final VideoTrack? track;

  bool get hasRenderer => publication?.subscribed == true && track != null;

  @override
  bool operator ==(Object other) {
    return other is _ParticipantVideoRenderState &&
        identical(other.publication, publication) &&
        identical(other.track, track);
  }

  @override
  int get hashCode => Object.hash(publication, track);
}

/// A LiveKit participant's camera video, filling its parent. Empty while the
/// camera is unpublished or unsubscribed. A muted camera keeps its renderer
/// mounted so unmuting doesn't flash.
class LiveKitParticipantVideo extends StatefulWidget {
  const LiveKitParticipantVideo({
    required this.participant,
    this.showStats = false,
    super.key,
  });

  final Participant<TrackPublication<Track>> participant;

  /// Adds a tap-to-toggle overlay with stream statistics.
  final bool showStats;

  @override
  State<LiveKitParticipantVideo> createState() =>
      _LiveKitParticipantVideoState();
}

class _LiveKitParticipantVideoState extends State<LiveKitParticipantVideo> {
  late _ParticipantVideoRenderState _renderState = _readRenderState();

  EventsListener<ParticipantEvent>? _listener;
  void _setupListeners() {
    _listener?.dispose();
    _listener = widget.participant.createListener()
      ..on<TrackPublishedEvent>(
        (event) => _onCameraPublicationChanged(event.publication),
      )
      ..on<TrackUnpublishedEvent>(
        (event) => _onCameraPublicationChanged(event.publication),
      )
      ..on<TrackSubscribedEvent>(
        (event) => _onCameraPublicationChanged(event.publication),
      )
      ..on<TrackUnsubscribedEvent>(
        (event) => _onCameraPublicationChanged(event.publication),
      )
      ..on<LocalTrackPublishedEvent>(
        (event) => _onCameraPublicationChanged(event.publication),
      )
      ..on<LocalTrackUnpublishedEvent>(
        (event) => _onCameraPublicationChanged(event.publication),
      )
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted);
  }

  void _onCameraPublicationChanged(TrackPublication<Track> publication) {
    if (!mounted || publication.source != TrackSource.camera) return;

    final nextState = _readRenderState();
    if (nextState == _renderState) return;
    setState(() => _renderState = nextState);
  }

  void _onTrackMuted(TrackMutedEvent event) {
    _onCameraPublicationChanged(event.publication);
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    _onCameraPublicationChanged(event.publication);
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void didUpdateWidget(covariant LiveKitParticipantVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid) {
      _setupListeners();
      _renderState = _readRenderState();
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  TrackPublication<Track>? get videoTrack {
    if (widget.participant is RemoteParticipant) {
      return widget.participant.getTrackPublicationBySource(TrackSource.camera);
    } else if (widget.participant is LocalParticipant) {
      return (widget.participant as LocalParticipant)
              .getTrackPublicationBySource(TrackSource.camera) ??
          widget.participant.videoTrackPublications
              .where((t) => t.track != null)
              .firstOrNull;
    } else {
      return widget.participant.videoTrackPublications
          .where((t) => t.track != null)
          .firstOrNull;
    }
  }

  _ParticipantVideoRenderState _readRenderState() {
    final publication = videoTrack;
    final track = publication?.track;
    return _ParticipantVideoRenderState(
      publication: publication,
      track: track is VideoTrack ? track : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderState = _renderState;
    final trackPublication = renderState.publication;

    final content = Stack(
      children: [
        if (renderState.hasRenderer)
          IgnorePointer(
            child: VideoTrackRenderer(
              key: ValueKey((trackPublication!.sid, renderState.track!.sid)),
              renderState.track!,
              fit: VideoViewFit.cover,
              renderMode: VideoRenderMode.platformView,
            ),
          ),
      ],
    );

    if (!widget.showStats) return content;

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned.fill(
          child: _ParticipantVideoStatistics(
            participant: widget.participant,
            trackPublication: trackPublication,
          ),
        ),
      ],
    );
  }
}

class _ParticipantVideoStatistics extends StatefulWidget {
  const _ParticipantVideoStatistics({
    required this.participant,
    required this.trackPublication,
  });

  final Participant<TrackPublication<Track>> participant;
  final TrackPublication<Track>? trackPublication;

  @override
  State<_ParticipantVideoStatistics> createState() =>
      _ParticipantVideoStatisticsState();
}

class _ParticipantVideoStatisticsState
    extends State<_ParticipantVideoStatistics> {
  // --- Debug Stats State ---
  int _currentBitrate = 0;
  num frameHeight = 0;
  num frameWidth = 0;
  num fps = 0;
  String? qualityLimitationReason;
  String? decoderImplementation;
  String? mimeType;

  void resetStats() {
    _currentBitrate = frameHeight = frameWidth = 0;
    qualityLimitationReason = decoderImplementation = mimeType = null;
    fps = 0;
  }

  EventsListener<TrackEvent>? _trackListener;
  String? _listenedTrackSid;

  void _setupListeners() {
    final track = widget.trackPublication?.track;
    final trackSid = track?.sid;

    if (_listenedTrackSid == trackSid && _trackListener != null) {
      return;
    }

    _trackListener?.dispose();
    _trackListener = null;
    _listenedTrackSid = trackSid;

    if (track != null) {
      _trackListener = track.createListener()..listen(_onTrackEvent);
    }
  }

  @override
  void initState() {
    super.initState();
    // When user is a local participant, the track is not inactive by default.
    if (widget.participant is LocalParticipant) {
      _isTrackInactive = false;
    } else {
      _isTrackInactive = true;
    }
    _setupListeners();
  }

  // Whether the track is inactive due to poor network conditions.
  late bool _isTrackInactive;

  void _onTrackEvent(TrackEvent event) {
    if (!mounted) return;

    if (event is VideoReceiverStatsEvent) {
      resetStats();

      final bitrate = event.currentBitrate;
      setState(() {
        frameHeight = event.stats.frameHeight ?? 0;
        frameWidth = event.stats.frameWidth ?? 0;
        fps = event.stats.framesPerSecond ?? 0;
        decoderImplementation = event.stats.decoderImplementation;
        mimeType = event.stats.mimeType;

        _currentBitrate = bitrate.round();
        _isTrackInactive = bitrate <= 0;
      });
    } else if (event is VideoSenderStatsEvent) {
      resetStats();

      setState(() {
        final stats = event.stats.values.lastOrNull;
        frameHeight = stats?.frameHeight ?? 0;
        frameWidth = stats?.frameWidth ?? 0;
        fps = stats?.framesPerSecond ?? 0;
        qualityLimitationReason = stats?.qualityLimitationReason;
        mimeType = stats?.mimeType;
        _currentBitrate = event.currentBitrate.round();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ParticipantVideoStatistics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid ||
        oldWidget.trackPublication?.track?.sid !=
            widget.trackPublication?.track?.sid) {
      _setupListeners();
    }
  }

  @override
  void dispose() {
    _trackListener?.dispose();
    super.dispose();
  }

  bool _shouldShowStatistics = kDebugMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          setState(() => _shouldShowStatistics = !_shouldShowStatistics),
      child: RepaintBoundary(
        child: _shouldShowStatistics
            ? Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Bitrate: $_currentBitrate\n'
                    'Res: ${frameWidth}x$frameHeight\n'
                    'FPS: $fps\n'
                    'Mime: ${mimeType ?? 'None'}\n'
                    'Is off: $_isTrackInactive',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
