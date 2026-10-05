import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;

/// `color-mix(in srgb, a amount, b)` — [amount] is how much of [a], 0 to 1.
Color mix(Color a, double amount, Color b) => Color.lerp(b, a, amount)!;

/// `color-mix(in srgb, a amount, transparent)` — [a] at [amount] of its alpha.
Color fade(Color a, double amount) => a.withValues(alpha: a.a * amount);

/// A `linear-gradient(<angle>deg, …)` that keeps the CSS angle on any box.
///
/// Flutter's [LinearGradient] runs between two alignments, so 142° on a
/// tall card would drift toward vertical. CSS instead runs the line at the
/// true angle and sizes it so the first and last stops touch the corners.
class CssLinearGradient extends Gradient {
  const CssLinearGradient({
    required this.angle,
    required super.colors,
    super.stops,
  });

  /// Degrees. 0 points up, 90 points right, same as CSS.
  final double angle;

  @override
  ui.Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final radians = angle * math.pi / 180;
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final half =
        (rect.width * direction.dx.abs() + rect.height * direction.dy.abs()) /
        2;
    return ui.Gradient.linear(
      rect.center - direction * half,
      rect.center + direction * half,
      colors,
      stops,
    );
  }

  @override
  Gradient scale(double factor) => CssLinearGradient(
    angle: angle,
    colors: [
      for (final color in colors) color.withValues(alpha: color.a * factor),
    ],
    stops: stops,
  );

  @override
  Gradient withOpacity(double opacity) => scale(opacity);
}

/// A `radial-gradient(<rx>% <ry>% at <x>% <y>%, …)` ellipse.
///
/// [RadialGradient] only draws circles. This one draws a circle in
/// shader space and squashes it into the CSS ellipse.
class CssRadialGradient extends Gradient {
  const CssRadialGradient({
    required this.radius,
    required this.center,
    required super.colors,
    super.stops,
  });

  /// Ellipse radii as fractions of the box: `80% 55%` is `Size(0.8, 0.55)`.
  final Size radius;

  /// Ellipse center as fractions of the box: `at 50% 22%` is `Offset(0.5, 0.22)`.
  final Offset center;

  @override
  ui.Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final origin =
        rect.topLeft + Offset(rect.width * center.dx, rect.height * center.dy);
    final rx = math.max(rect.width * radius.width, 0.001);
    final ry = math.max(rect.height * radius.height, 0.001);
    final squash = Matrix4.identity()
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..scaleByDouble(1, ry / rx, 1, 1)
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
    return ui.Gradient.radial(
      origin,
      rx,
      colors,
      stops,
      TileMode.clamp,
      squash.storage,
    );
  }

  @override
  Gradient scale(double factor) => CssRadialGradient(
    radius: radius,
    center: center,
    colors: [
      for (final color in colors) color.withValues(alpha: color.a * factor),
    ],
    stops: stops,
  );

  @override
  Gradient withOpacity(double opacity) => scale(opacity);
}

/// CSS `clamp(min, value, max)`.
double clampPx(double min, double value, double max) =>
    value.clamp(min, max).toDouble();
