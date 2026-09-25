import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/utils/frame_paced_ticker.dart';

@immutable
class AudioVisualizerWidgetOptions {
  const AudioVisualizerWidgetOptions({
    this.barCount = 7,
    this.centeredBands = true,
    this.width = 12,
    this.minHeight = 12,
    this.maxHeight = 100,
    this.durationInMilliseconds = 500,
    this.color,
    this.spacing = 5,
    this.cornerRadius = 9999,
    this.barMinOpacity = 0.2,
  });
  final int barCount;
  final bool centeredBands;
  final double width;
  final double minHeight;
  final double maxHeight;
  final int durationInMilliseconds;
  final Color? color;
  final double spacing;
  final double cornerRadius;
  final double barMinOpacity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioVisualizerWidgetOptions &&
        other.barCount == barCount &&
        other.centeredBands == centeredBands &&
        other.width == width &&
        other.minHeight == minHeight &&
        other.maxHeight == maxHeight &&
        other.durationInMilliseconds == durationInMilliseconds &&
        other.color == color &&
        other.spacing == spacing &&
        other.cornerRadius == cornerRadius &&
        other.barMinOpacity == barMinOpacity;
  }

  @override
  int get hashCode {
    return Object.hash(
      barCount,
      centeredBands,
      width,
      minHeight,
      maxHeight,
      durationInMilliseconds,
      color,
      spacing,
      cornerRadius,
      barMinOpacity,
    );
  }
}

extension AudioVisualizerColor on AudioVisualizerWidgetOptions {
  Color computeColor(BuildContext ctx) =>
      color ?? Theme.of(ctx).colorScheme.primary;
}

class BarsViewItem {
  const BarsViewItem({required this.value, required this.color});

  final double value;
  final Color color;
}

/// One-pixel-wide bars with a shared ticker for height and color interpolation.
class BarsView extends StatelessWidget {
  const BarsView({required this.options, required this.elements, super.key});
  final AudioVisualizerWidgetOptions options;
  final List<BarsViewItem> elements;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (elements.isEmpty) return const SizedBox.shrink();
      final delta = (constraints.maxWidth / elements.length) - options.spacing;
      return _AnimatedBars(
        duration: Duration(
          milliseconds: options.durationInMilliseconds ~/ options.barCount,
        ),
        heights: [
          for (final element in elements)
            clampDouble(
              max(
                delta,
                element.value * (constraints.maxHeight - delta) + delta,
              ),
              0,
              options.maxHeight,
            ),
        ],
        colors: [for (final element in elements) element.color],
        cornerRadius: options.cornerRadius,
        spacing: options.spacing,
        height: constraints.maxHeight,
        textDirection: Directionality.of(context),
      );
    },
  );
}

class _AnimatedBars extends ImplicitlyAnimatedWidget {
  const _AnimatedBars({
    required super.duration,
    required this.heights,
    required this.colors,
    required this.cornerRadius,
    required this.spacing,
    required this.height,
    required this.textDirection,
  });

  final List<double> heights;
  final List<Color> colors;
  final double cornerRadius;
  final double spacing;
  final double height;
  final TextDirection textDirection;

  @override
  ImplicitlyAnimatedWidgetState<_AnimatedBars> createState() =>
      _AnimatedBarsState();
}

class _AnimatedBarsState extends ImplicitlyAnimatedWidgetState<_AnimatedBars>
    with FramePacedTickerProviderStateMixin {
  List<Tween<double>> _heights = [];
  List<ColorTween> _colors = [];
  Tween<double>? _radius;

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
    _colors = [
      for (var i = 0; i < widget.colors.length; i++)
        visitor(
              i < _colors.length ? _colors[i] : null,
              widget.colors[i],
              (value) => ColorTween(begin: value as Color),
            )!
            as ColorTween,
    ];
    _radius =
        visitor(
              _radius,
              widget.cornerRadius,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(
      widget.heights.length + (widget.heights.length - 1) * widget.spacing,
      widget.height,
    ),
    painter: _BarsPainter(
      animation: animation,
      heights: _heights,
      colors: _colors,
      radius: _radius!,
      spacing: widget.spacing,
      textDirection: widget.textDirection,
    ),
  );
}

/// Animation ticks repaint the bars without rebuilding or laying out widgets.
class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.animation,
    required this.heights,
    required this.colors,
    required this.radius,
    required this.spacing,
    required this.textDirection,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Tween<double>> heights;
  final List<ColorTween> colors;
  final Tween<double> radius;
  final double spacing;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cellWidth =
        (size.width - (heights.length - 1) * spacing) / heights.length;
    final corner = Radius.circular(radius.evaluate(animation));
    final paint = Paint();
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
          corner,
        ),
        paint..color = colors[i].evaluate(animation)!,
      );
    }
  }

  // Tween endpoints are updated in place when samples or options change.
  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => true;

  @override
  bool shouldRebuildSemantics(_BarsPainter oldDelegate) => false;
}
