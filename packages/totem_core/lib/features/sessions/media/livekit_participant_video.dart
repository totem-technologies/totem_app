import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_selector.dart';

@immutable
class _ParticipantVideoRenderState {
  const new({required this.isLocal, required this.publication, this.track});

  /// Whether the participant is local, or null when there is no participant.
  final bool? isLocal;
  final TrackPublication<Track>? publication;
  final VideoTrack? track;

  bool get hasRenderer => publication?.subscribed == true && track != null;

  @override
  bool operator ==(Object other) {
    return other is _ParticipantVideoRenderState &&
        other.isLocal == isLocal &&
        identical(other.publication, publication) &&
        identical(other.track, track);
  }

  @override
  int get hashCode => Object.hash(isLocal, publication, track);
}

/// A LiveKit participant's camera video, filling its parent. Empty while the
/// camera is unpublished or unsubscribed. A muted camera keeps its renderer
/// mounted so unmuting doesn't flash.
class LiveKitParticipantVideo extends StatelessWidget {
  const new({
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

  _ParticipantVideoRenderState _read() {
    final participant = this.participant();
    final publication = participant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    return _ParticipantVideoRenderState(
      isLocal: participant == null ? null : participant is LocalParticipant,
      publication: publication,
      track: track is VideoTrack ? track : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiveKitSelector(
      changes: changes,
      read: _read,
      builder: (context, renderState) {
        final publication = renderState.publication;
        final track = renderState.track;
        final content = Stack(
          children: [
            if (renderState.hasRenderer)
              IgnorePointer(
                child: VideoTrackRenderer(
                  key: ValueKey((publication!.sid, track!.sid)),
                  track,
                  fit: VideoViewFit.cover,
                  renderMode: VideoRenderMode.platformView,
                ),
              ),
          ],
        );

        final isLocal = renderState.isLocal;
        if (!showStats || isLocal == null) return content;

        return Stack(
          fit: StackFit.expand,
          children: [
            content,
            Positioned.fill(
              child: _ParticipantVideoStatistics(
                isLocal: isLocal,
                track: track,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParticipantVideoStatistics extends StatefulWidget {
  const new({required this.isLocal, required this.track});

  final bool isLocal;
  final VideoTrack? track;

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

  void _setupListeners() {
    final track = widget.track;
    _trackListener?.dispose();
    _trackListener = null;
    if (track != null) {
      _trackListener = track.createListener()..listen(_onTrackEvent);
    }
  }

  @override
  void initState() {
    super.initState();
    // Local tracks start live. Remote ones count as inactive until stats
    // report a bitrate.
    _isTrackInactive = !widget.isLocal;
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
    if (!identical(oldWidget.track, widget.track)) _setupListeners();
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
