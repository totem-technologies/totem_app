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

/// Audio level bars measured from a microphone track, or a microphone-off
/// icon while it is muted or missing. An unmuted microphone always renders
/// bars; silence settles to small dots.
///
/// Native platforms use the SDK visualizer. Web uses samples from the track's
/// browser audio analyser.
class LiveKitMicrophoneLevel extends StatelessWidget {
  const LiveKitMicrophoneLevel({
    required this.track,
    required this.changes,
    required this.color,
    required this.barCount,
    this.microphoneOn,
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

  /// Resolves the microphone's published mute state when the track has not
  /// been subscribed locally yet.
  final bool Function()? microphoneOn;

  final double iconSize;

  ({bool microphoneOn, AudioTrack? track}) _read() {
    final track = this.track();
    final microphoneOn =
        this.microphoneOn?.call() ?? (track != null && !track.muted);
    return (
      microphoneOn: microphoneOn,
      track: microphoneOn && track != null && !track.muted ? track : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiveKitSelector(
      changes: changes,
      read: _read,
      builder: (context, reading) {
        if (!reading.microphoneOn) {
          return TotemIcon(
            TotemIcons.microphoneOff,
            size: iconSize,
            color: color,
          );
        }
        final track = reading.track;
        if (track == null) {
          return LevelBars(
            levels: List.filled(barCount, 0, growable: false),
            color: color,
          );
        }
        if (kIsWeb) {
          return _WebWaveform(
            track: track,
            barCount: barCount,
            color: color,
          );
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

class _WebWaveform extends StatefulWidget {
  const _WebWaveform({
    required this.track,
    required this.barCount,
    required this.color,
  });

  final AudioTrack track;
  final int barCount;
  final Color color;

  @override
  State<_WebWaveform> createState() => _WebWaveformState();
}

class _WebWaveformState extends State<_WebWaveform> {
  StreamSubscription<List<double>>? _subscription;
  List<double> _levels = const [];
  bool _isSpeaking = false;

  void _listen() {
    unawaited(_subscription?.cancel());
    _levels = List.filled(widget.barCount, 0, growable: false);
    _isSpeaking = false;
    _subscription = localAudioLevels(widget.track, barCount: widget.barCount)
        .listen((levels) {
          final isSpeaking = webWaveformIsActive(
            levels,
            wasActive: _isSpeaking,
          );
          final nextLevels = isSpeaking
              ? levels
              : List<double>.filled(widget.barCount, 0, growable: false);
          if (!audioVisualizerSamplesChanged(_levels, nextLevels) &&
              isSpeaking == _isSpeaking) {
            return;
          }
          setState(() {
            _levels = nextLevels;
            _isSpeaking = isSpeaking;
          });
        });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _WebWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) _listen();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LevelBars(levels: _levels, color: widget.color);
}
