import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/local_audio_bands.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Audio level bars measured on this device for a local microphone track,
/// or a microphone-off icon while it is muted or missing.
///
/// On web the bars come from [localAudioBands], which redraws only when the
/// levels change; native platforms use the SDK visualizer.
class LiveKitMicrophoneLevel extends StatefulWidget {
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

  @override
  State<LiveKitMicrophoneLevel> createState() => _LiveKitMicrophoneLevelState();
}

class _LiveKitMicrophoneLevelState extends State<LiveKitMicrophoneLevel> {
  StreamSubscription<void>? _subscription;
  late AudioTrack? _track = _read();

  /// The track while it is unmuted.
  AudioTrack? _read() {
    final track = widget.track();
    return track == null || track.muted ? null : track;
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = widget.changes.listen((_) {
      final next = _read();
      if (identical(next, _track) || !mounted) return;
      setState(() => _track = next);
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LiveKitMicrophoneLevel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) _listen();
    _track = _read();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    if (track == null) {
      return TotemIcon(
        TotemIcons.microphoneOff,
        size: widget.iconSize,
        color: widget.color,
      );
    }
    if (kIsWeb) {
      return _WebLevelBars(
        track: track,
        barCount: widget.barCount,
        color: widget.color,
      );
    }
    return SoundWaveformWidget(
      audioTrack: track,
      barCount: widget.barCount,
      color: widget.color,
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
    return LevelBars(levels: _levels, color: widget.color);
  }
}
