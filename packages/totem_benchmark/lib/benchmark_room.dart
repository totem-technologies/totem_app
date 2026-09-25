import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/adaptive_call_layout.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer_bars.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';
import 'package:totem_core/features/sessions/widgets/participant_tile_surface.dart';
import 'package:totem_core/features/sessions/widgets/session_status_notice.dart';
import 'package:totem_core/features/sessions/widgets/smart_name_text.dart';

import 'benchmark_config.dart';

/// Rendering workload with media supplied independently of a room connection.
class BenchmarkRoom extends StatelessWidget {
  const BenchmarkRoom({
    required this.config,
    required this.videoBuilder,
    super.key,
  });

  final BenchmarkConfig config;
  final Widget Function(int participant, VideoMode mode) videoBuilder;

  Widget _tile(int id) => ParticipantTileSurface(
    key: ValueKey(id),
    clipBehavior: switch (config.clip) {
      TileClip.antiAlias => Clip.antiAlias,
      TileClip.hardEdge => Clip.hardEdge,
      TileClip.none || TileClip.css => Clip.none,
    },
    children: [
      Positioned.fill(child: videoBuilder(id, config.video)),
      if (config.overlays)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = ParticipantOverlayMetrics.forCard(
                constraints.biggest,
              );
              return Stack(
                children: [
                  if (config.waveform != WaveformMode.hidden)
                    PositionedDirectional(
                      top: metrics.cornerInset,
                      start: metrics.cornerInset,
                      child: Container(
                        width: metrics.badgeSize,
                        height: metrics.badgeSize,
                        padding: EdgeInsets.all(metrics.badgePadding),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                          boxShadow: kElevationToShadow[6],
                        ),
                        child: RepaintBoundary(
                          child: SyntheticWaveform(
                            participant: id,
                            mode: config.waveform,
                          ),
                        ),
                      ),
                    ),
                  PositionedDirectional(
                    bottom: 8,
                    start: 8,
                    end: 8,
                    child: SmartNameText(
                      name: 'Participant ${id + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => RoomBackground(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(child: Text('Room rendering benchmark')),
                TickerMode(
                  enabled: config.notice,
                  child: const SessionStatusNotice(
                    label: 'Starting soon',
                    message: 'Waiting for the session',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AdaptiveCallLayout(
              speaker: _tile(0),
              participants: [
                for (var id = 1; id < config.participants; id++) _tile(id),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Local video · synthetic audio levels'),
          ),
        ],
      ),
    ),
  );
}

/// Feeds deterministic levels at the same 140 ms cadence as the call's audio
/// visualizer. BarsView owns the production interpolation and painting.
class SyntheticWaveform extends StatefulWidget {
  const SyntheticWaveform({
    required this.participant,
    required this.mode,
    super.key,
  });

  final int participant;
  final WaveformMode mode;

  @override
  State<SyntheticWaveform> createState() => _SyntheticWaveformState();
}

class _SyntheticWaveformState extends State<SyntheticWaveform> {
  Timer? _timer;
  int _sample = 0;

  void _updateTimer() {
    _timer?.cancel();
    _timer = widget.mode == WaveformMode.animated
        ? Timer.periodic(const Duration(milliseconds: 140), (_) {
            setState(() => _sample++);
          })
        : null;
  }

  @override
  void initState() {
    super.initState();
    _updateTimer();
  }

  @override
  void didUpdateWidget(SyntheticWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _updateTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => BarsView(
      options: AudioVisualizerWidgetOptions(
        color: Colors.white,
        barCount: 3,
        spacing: 2.5,
        barMinOpacity: 0.8,
        minHeight: constraints.maxHeight * 0.2,
        maxHeight: constraints.maxHeight,
      ),
      elements: [
        for (var bar = 0; bar < 3; bar++)
          BarsViewItem(
            value:
                0.1 +
                0.8 *
                    math
                        .sin(_sample * 0.9 + bar * 1.7 + widget.participant)
                        .abs(),
            color: Colors.white,
          ),
      ],
    ),
  );
}
