import 'package:flutter/painting.dart';

/// Effect styles — not Figma variables. Named here so components never
/// invent a shadow.
///
/// Mapping:
///   Totem/Elevation 1   → [Shadows.elevation1]   (y:2, blur:8, rgba(0,0,0,0.08))
///   Totem/Elevation 2   → [Shadows.elevation2]   (y:4, blur:20, rgba(0,0,0,0.12))
///   Totem/Frosted Glass → [Shadows.frostedGlassBlur]  (background blur 80)
abstract final class Shadows {
  static const elevation1 = [
    BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x14000000)),
  ];

  static const elevation2 = [
    BoxShadow(offset: Offset(0, 4), blurRadius: 20, color: Color(0x1F000000)),
  ];

  /// Figma blur radius. Flutter's image filter takes a sigma, which is half.
  static const frostedGlassBlur = 80.0;
}
