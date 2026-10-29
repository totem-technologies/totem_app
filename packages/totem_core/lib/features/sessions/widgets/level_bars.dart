import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/utils/frame_paced_ticker.dart';

/// Audio level bars: one-pixel-wide rounded bars that ease to new heights.
/// They animate only when [levels] change, so a quiet microphone costs no
/// frames.
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
    final scaled = level.clamp(0.0, 1.0);
    return LevelBars(
      key: key,
      color: color,
      levels: List.filled(barCount, scaled),
    );
  }

  /// One value between 0 and 1 per bar.
  final List<double> levels;
  final Color color;

  static const _spacing = 2.5;

  /// Keeps edge bars inside circular microphone badges visually balanced.
  static double _edgeScale(int index, int barCount) {
    final center = (barCount - 1) / 2;
    return 1 - 0.2 * ((index - center).abs() / math.max(center, 1));
  }

  /// How long all the bars together take to reach new levels.
  static const _transitionMilliseconds = 500;

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A silent bar is a dot as tall as its cell is wide.
          final dot = (constraints.maxWidth / levels.length) - _spacing;
          return _AnimatedBars(
            duration: Duration(
              milliseconds: _transitionMilliseconds ~/ levels.length,
            ),
            heights: [
              for (var i = 0; i < levels.length; i++)
                math.max(
                  dot,
                  levels[i] *
                          _edgeScale(i, levels.length) *
                          (constraints.maxHeight - dot) +
                      dot,
                ),
            ],
            color: color,
            height: constraints.maxHeight,
            textDirection: Directionality.of(context),
          );
        },
      ),
    );
  }
}

class _AnimatedBars extends StatefulWidget {
  const _AnimatedBars({
    required this.duration,
    required this.heights,
    required this.color,
    required this.height,
    required this.textDirection,
  });

  final Duration duration;
  final List<double> heights;
  final Color color;
  final double height;
  final TextDirection textDirection;

  @override
  State<_AnimatedBars> createState() => _AnimatedBarsState();
}

/// Eases each bar from where it is towards its latest height, like an
/// implicit animation, but keeps easing when the system reduces motion:
/// bars that jump read as flicker rather than calm.
class _AnimatedBarsState extends State<_AnimatedBars>
    with FramePacedTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  late List<Tween<double>> _heights = [
    for (final height in widget.heights) Tween(begin: height, end: height),
  ];
  late ColorTween _color = ColorTween(begin: widget.color, end: widget.color);

  @override
  void didUpdateWidget(covariant _AnimatedBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    var retarget = _color.end != widget.color;
    for (var i = 0; i < widget.heights.length && i < _heights.length; i++) {
      if (_heights[i].end != widget.heights[i]) retarget = true;
    }
    if (!retarget) {
      // Added bars appear at their height; removed ones go.
      _heights = [
        for (var i = 0; i < widget.heights.length; i++)
          if (i < _heights.length)
            _heights[i]
          else
            Tween(begin: widget.heights[i], end: widget.heights[i]),
      ];
      return;
    }
    _heights = [
      for (var i = 0; i < widget.heights.length; i++)
        Tween(
          begin: i < _heights.length
              ? _heights[i].evaluate(_controller)
              : widget.heights[i],
          end: widget.heights[i],
        ),
    ];
    _color = ColorTween(begin: _color.evaluate(_controller), end: widget.color);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(
      widget.heights.length + (widget.heights.length - 1) * LevelBars._spacing,
      widget.height,
    ),
    painter: _BarsPainter(
      animation: _controller,
      heights: _heights,
      color: _color,
      textDirection: widget.textDirection,
    ),
  );
}

/// Animation ticks repaint the bars without rebuilding or laying out widgets.
class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.animation,
    required this.heights,
    required this.color,
    required this.textDirection,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Tween<double>> heights;
  final ColorTween color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const spacing = LevelBars._spacing;
    final cellWidth =
        (size.width - (heights.length - 1) * spacing) / heights.length;
    final paint = Paint()..color = color.evaluate(animation)!;
    for (var i = 0; i < heights.length; i++) {
      final slot = textDirection == TextDirection.ltr
          ? i
          : heights.length - i - 1;
      final height = clampDouble(
        heights[i].evaluate(animation),
        0,
        size.height,
      );
      final center = Offset(
        cellWidth * (slot + 0.5) + spacing * slot,
        size.height / 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 1, height: height),
          const Radius.circular(0.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      !identical(oldDelegate.heights, heights) ||
      !identical(oldDelegate.color, color) ||
      oldDelegate.textDirection != textDirection;

  @override
  bool shouldRebuildSemantics(_BarsPainter oldDelegate) => false;
}
