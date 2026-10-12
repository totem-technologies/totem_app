import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/utils/frame_paced_ticker.dart';

/// Audio level bars: one-pixel-wide rounded bars that ease to new heights.
/// They animate only when [levels] change, so a quiet microphone costs no
/// frames.
class LevelBars extends StatelessWidget {
  const new({required this.levels, required this.color, super.key});

  /// Bars shaped from a single [level] between 0 and 1: tallest in the
  /// middle, tapering to the sides.
  factory fromLevel(
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

  static const _spacing = 2.5;

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
              for (final level in levels)
                math.max(dot, level * (constraints.maxHeight - dot) + dot),
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

class _AnimatedBars extends ImplicitlyAnimatedWidget {
  const new({
    required super.duration,
    required this.heights,
    required this.color,
    required this.height,
    required this.textDirection,
  });

  final List<double> heights;
  final Color color;
  final double height;
  final TextDirection textDirection;

  @override
  ImplicitlyAnimatedWidgetState<_AnimatedBars> createState() =>
      _AnimatedBarsState();
}

class _AnimatedBarsState extends ImplicitlyAnimatedWidgetState<_AnimatedBars>
    with FramePacedTickerProviderStateMixin {
  List<Tween<double>> _heights = [];
  ColorTween? _color;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _heights = [
      for (var i = 0; i < widget.heights.length; i++)
        visitor(
              i < _heights.length ? _heights[i] : null,
              widget.heights[i],
              (value) => Tween<double>(begin: value as double),
            )!
            as Tween<double>,
    ];
    _color = visitor(
      _color,
      widget.color,
      (value) => ColorTween(begin: value as Color),
    ) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(
      widget.heights.length + (widget.heights.length - 1) * LevelBars._spacing,
      widget.height,
    ),
    painter: _BarsPainter(
      animation: animation,
      heights: _heights,
      color: _color!,
      textDirection: widget.textDirection,
    ),
  );
}

/// Animation ticks repaint the bars without rebuilding or laying out widgets.
class _BarsPainter extends CustomPainter {
  new({
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

  // Tween endpoints are updated in place when the levels change.
  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => true;

  @override
  bool shouldRebuildSemantics(_BarsPainter oldDelegate) => false;
}
