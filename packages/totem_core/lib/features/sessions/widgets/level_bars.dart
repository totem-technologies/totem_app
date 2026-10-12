import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer_bars.dart';

/// Audio level bars. They animate only when [levels] change, so a quiet
/// microphone costs no frames.
class LevelBars extends StatelessWidget {
  const LevelBars({required this.levels, required this.color, super.key});

  /// Bars shaped from a single [level] between 0 and 1: tallest in the
  /// middle, tapering to the sides.
  factory LevelBars.fromLevel(
    double level, {
    required int barCount,
    required Color color,
    Key? key,
  }) {
    // Speech levels sit low on LiveKit's linear scale; the square root
    // spreads them over the bar height.
    final scaled = math.sqrt(level.clamp(0.0, 1.0));
    final center = (barCount - 1) / 2;
    return LevelBars(
      key: key,
      color: color,
      levels: [
        for (var i = 0; i < barCount; i++)
          scaled * (1 - 0.4 * ((i - center).abs() / math.max(center, 1))),
      ],
    );
  }

  /// One value between 0 and 1 per bar.
  final List<double> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RepaintBoundary(
        child: BarsView(
          options: AudioVisualizerWidgetOptions(
            color: color,
            barCount: levels.length,
            barMinOpacity: 0.8,
            spacing: 2.5,
            minHeight: constraints.maxHeight * 0.2,
            maxHeight: constraints.maxHeight,
          ),
          elements: [
            for (final level in levels)
              BarsViewItem(value: level, color: color),
          ],
        ),
      ),
    );
  }
}
