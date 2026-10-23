import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/media/livekit_selector.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/local_audio_level.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Audio level bars measured on this device for a local microphone track,
/// or a microphone-off icon while it is muted or missing.
///
/// On web the bars come from [localAudioLevel], on the same scale as remote
/// speakers' bars, and redraw only when the level changes. Native platforms
/// use the SDK visualizer.
class LiveKitMicrophoneLevel extends StatelessWidget {
  const LiveKitMicrophoneLevel({
    required this.track,
    required this.changes,
    required this.color,
    required this.barCount,
    this.iconSize = 20,
    super.key,
  });

  /// Bars for a standalone [track], such as the pre-join preview.
  LiveKitMicrophoneLevel.preview(
    AudioTrack track, {
    required Color color,
    required int barCount,
    double iconSize = 20,
    Key? key,
  }) : this(
         track: () => track,
         changes: trackChanges(track),
         color: color,
         barCount: barCount,
         iconSize: iconSize,
         key: key,
       );

  /// Looks up the track on every change, so the bars follow republishing.
  final AudioTrack? Function() track;

  /// Emits whenever the track may have changed or been muted.
  final Stream<void> changes;

  final Color color;
  final int barCount;
  final double iconSize;

  /// The track while it is unmuted.
  AudioTrack? _read() {
    final track = this.track();
    return track == null || track.muted ? null : track;
  }

  @override
  Widget build(BuildContext context) {
    return LiveKitSelector(
      changes: changes,
      read: _read,
      builder: (context, track) {
        if (track == null) {
          return TotemIcon(
            TotemIcons.microphoneOff,
            size: iconSize,
            color: color,
          );
        }
        if (kIsWeb) {
          return _WebLevelBars(track: track, barCount: barCount, color: color);
        }
        return SoundWaveformWidget(
          audioTrack: track,
          barCount: barCount,
          color: color,
        );
      },
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
  final Color color;

  @override
  State<_WebLevelBars> createState() => _WebLevelBarsState();
}

class _WebLevelBarsState extends State<_WebLevelBars> {
  StreamSubscription<double>? _subscription;
  var _level = 0.0;

  void _listen() {
    unawaited(_subscription?.cancel());
    _level = 0;
    _subscription = localAudioLevel(
      widget.track,
    ).listen((level) => setState(() => _level = level));
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _WebLevelBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) _listen();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LevelBars.fromLevel(
      _level,
      barCount: widget.barCount,
      color: widget.color,
    );
  }
}
