import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/utils/frame_paced_ticker.dart';

/// Audio level bars: one-pixel-wide rounded bars that ease to new heights.
///
/// New [levels] only retarget the easing; every frame comes from the shared
/// [FramePacedTicker] clock. On the web, any Flutter frame re-renders the
/// canvases over the video tiles, so the bars' cost follows their frame rate
/// rather than their size. They animate only when [levels] change, so a quiet
/// microphone costs no frames.
class LevelBars extends StatefulWidget {
  const LevelBars({required this.levels, required this.color, super.key});

  /// Bars that never move, such as idle dots for a silent microphone.
  LevelBars.fixed(List<double> levels, {required Color color, Key? key})
    : this(levels: _FixedLevels(levels), color: color, key: key);

  /// One value between 0 and 1 per bar.
  final ValueListenable<List<double>> levels;
  final Color color;

  static const _spacing = 2.5;

  /// How long all the bars together take to reach new levels.
  static const _transitionMilliseconds = 500;

  @override
  State<LevelBars> createState() => _LevelBarsState();
}

class _FixedLevels implements ValueListenable<List<double>> {
  _FixedLevels(this.value);

  @override
  final List<double> value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Eases each bar from where it is towards its latest level, like an implicit
/// animation, but keeps easing when the system reduces motion: bars that jump
/// read as flicker rather than calm.
class _LevelBarsState extends State<LevelBars>
    with FramePacedTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier(0);

  late List<double> _from;
  late List<double> _to;
  late List<double> _shown;
  late Color _fromColor;
  late Color _toColor;
  late Color _shownColor;

  Duration get _duration => Duration(
    milliseconds: LevelBars._transitionMilliseconds ~/ math.max(1, _to.length),
  );

  void _retarget() {
    final next = widget.levels.value;
    if (listEquals(next, _to) && widget.color == _toColor) return;
    // Added bars appear at their level; removed ones go.
    _from = [
      for (var i = 0; i < next.length; i++)
        if (i < _shown.length) _shown[i] else next[i],
    ];
    _to = List.of(next, growable: false);
    _fromColor = _shownColor;
    _toColor = widget.color;
    if (_shown.length != _to.length) {
      _shown = _from;
      _repaint.value++;
    }
    // Restarting only requests a paced tick; nothing repaints until then.
    _ticker
      ..stop()
      ..start();
  }

  void _tick(Duration elapsed) {
    // The first paced frame lands up to one clock interval after the request,
    // so progress starts one interval in rather than repainting the start.
    final duration = _duration.inMicroseconds;
    final t = duration == 0
        ? 1.0
        : ((elapsed + FramePacedTicker.interval).inMicroseconds / duration)
              .clamp(0.0, 1.0);
    _shown = [
      for (var i = 0; i < _to.length; i++) _from[i] + (_to[i] - _from[i]) * t,
    ];
    _shownColor = Color.lerp(_fromColor, _toColor, t)!;
    _repaint.value++;
    if (t >= 1) _ticker.stop();
  }

  @override
  void initState() {
    super.initState();
    _from = _to = _shown = List.of(widget.levels.value, growable: false);
    _fromColor = _toColor = _shownColor = widget.color;
    _ticker = createTicker(_tick);
    widget.levels.addListener(_retarget);
  }

  @override
  void didUpdateWidget(LevelBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.levels, widget.levels)) {
      oldWidget.levels.removeListener(_retarget);
      widget.levels.addListener(_retarget);
    }
    _retarget();
  }

  @override
  void dispose() {
    widget.levels.removeListener(_retarget);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.expand(
      child: CustomPaint(
        painter: _BarsPainter(
          state: this,
          textDirection: Directionality.of(context),
        ),
      ),
    ),
  );
}

/// Ticks repaint the bars without rebuilding or laying out widgets.
class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.state, required this.textDirection})
    : super(repaint: state._repaint);

  final _LevelBarsState state;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final levels = state._shown;
    if (size.isEmpty || levels.isEmpty) return;
    const spacing = LevelBars._spacing;
    final count = levels.length;
    final cellWidth = (size.width - (count - 1) * spacing) / count;
    // A silent bar is a dot as tall as its cell is wide.
    final dot = size.width / count - spacing;
    final center = (count - 1) / 2;
    final paint = Paint()..color = state._shownColor;
    for (var i = 0; i < count; i++) {
      final slot = textDirection == TextDirection.ltr ? i : count - i - 1;
      // Keeps edge bars inside circular microphone badges visually balanced.
      final edge = 1 - 0.2 * ((i - center).abs() / math.max(center, 1));
      final height = clampDouble(
        math.max(dot, levels[i] * edge * (size.height - dot) + dot),
        0,
        size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              cellWidth * (slot + 0.5) + spacing * slot,
              size.height / 2,
            ),
            width: 1,
            height: height,
          ),
          const Radius.circular(0.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      !identical(oldDelegate.state, state) ||
      oldDelegate.textDirection != textDirection;

  @override
  bool shouldRebuildSemantics(_BarsPainter oldDelegate) => false;
}
