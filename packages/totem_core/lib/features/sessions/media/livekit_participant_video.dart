import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:material_ui/material_ui.dart';

@immutable
class _ParticipantVideoRenderState {
  const _ParticipantVideoRenderState({
    required this.participant,
    required this.publication,
    required this.track,
  });

  final Participant? participant;
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
  int get hashCode => Object.hash(participant, publication, track);
}

/// A LiveKit participant's camera video, filling its parent. Empty while the
/// camera is unpublished or unsubscribed. A muted camera keeps its renderer
/// mounted so unmuting doesn't flash.
class LiveKitParticipantVideo extends StatefulWidget {
  const LiveKitParticipantVideo({
    required this.participant,
    required this.changes,
    this.showStats = false,
    super.key,
  });

  /// Looks up the participant on every change, so the video follows them
  /// across a rejoin.
  final Participant? Function() participant;

  /// Emits whenever a participant's tracks may have changed.
  final Stream<void> changes;

  /// Adds a tap-to-toggle overlay with stream statistics.
  final bool showStats;

  @override
  State<LiveKitParticipantVideo> createState() =>
      _LiveKitParticipantVideoState();
}

class _LiveKitParticipantVideoState extends State<LiveKitParticipantVideo> {
  late _ParticipantVideoRenderState _renderState = _read();
  StreamSubscription<void>? _subscription;

  _ParticipantVideoRenderState _read() {
    final participant = widget.participant();
    final publication = participant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    return _ParticipantVideoRenderState(
      participant: participant,
      publication: publication,
      track: track is VideoTrack ? track : null,
    );
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = widget.changes.listen((_) {
      final next = _read();
      if (next == _renderState || !mounted) return;
      setState(() => _renderState = next);
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LiveKitParticipantVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) _listen();
    _renderState = _read();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderState = _renderState;
    final participant = renderState.participant;
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

    if (!widget.showStats || participant == null) return content;

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned.fill(
          child: _ParticipantVideoStatistics(
            participant: participant,
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
