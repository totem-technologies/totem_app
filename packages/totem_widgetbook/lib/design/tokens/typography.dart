import 'package:flutter/painting.dart';

/// Text styles from the Totem file.
///
/// Totem/* is the live type ramp (Design System Spec).
/// Heading 1/2/3 + Body 1/2/3 are older styles still bound on some screens.
///
/// Mapping (Figma style → Dart):
///   Totem/Display            → [TotemText.display]
///   Totem/H1                 → [TotemText.h1]
///   Totem/H2                 → [TotemText.h2]
///   Totem/H3                 → [TotemText.h3]
///   Totem/H4                 → [TotemText.h4]
///   Totem/H4 Medium          → [TotemText.h4Medium]
///   Totem/Body               → [TotemText.body]
///   Totem/Body Bold          → [TotemText.bodyBold]
///   Totem/Body Small         → [TotemText.bodySmall]
///   Totem/Body Small Bold    → [TotemText.bodySmallBold]
///   Totem/Caption            → [TotemText.caption]
///   Totem/Caption Medium     → [TotemText.captionMedium]
///   Totem/Caption Bold       → [TotemText.captionBold]
///   Totem/Overline           → [TotemText.overline]
///   Totem/Overline Bold      → [TotemText.overlineBold]
///   Totem/Button Large       → [TotemText.buttonLarge]
///   Totem/Button             → [TotemText.button]
///   Totem/Button Small       → [TotemText.buttonSmall]
///   Totem/Numeric Large      → [TotemText.numericLarge]
///   Totem/Numeric            → [TotemText.numeric]
///   Totem/Numeric Small      → [TotemText.numericSmall]
///   Heading 1                → [TotemText.heading1]   (same metrics as Display)
///   Heading 2                → [TotemText.heading2]   (same metrics as H1)
///   Heading 3                → [TotemText.heading3]   (same metrics as H2)
///   Body 1                   → [TotemText.body1]      (16 / 400 / 1.2 — not Totem/Body)
///   Body 2                   → [TotemText.body2]      (12 / 400 / 1.2 — not Caption)
///   Body 3                   → [TotemText.body3]      (9 / 400 / 1.2 — no Totem twin)
///
/// Every style splits leading evenly above and below the glyphs, the way
/// Figma and CSS line-height do. Flutter's default puts it all on top.
abstract final class TotemText {
  static const fontFamily = 'Montserrat';

  static const _base = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Totem ramp — Design System Spec

  /// Totem/Display — 38 SemiBold 120%
  static final display = _base.copyWith(
    fontSize: 38,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Totem/H1 — 28 SemiBold 120%
  static final h1 = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Totem/H2 — 21 SemiBold 120%
  static final h2 = _base.copyWith(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Totem/H3 — 18 SemiBold 120%
  static final h3 = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Totem/H4 — 16 SemiBold 130%
  static final h4 = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Totem/H4 Medium — 16 Medium 130%
  static final h4Medium = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Totem/Body — 16 Regular 150%
  static final body = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Totem/Body Bold — 16 SemiBold 150%
  static final bodyBold = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// Totem/Body Small — 14 Regular 150%
  static final bodySmall = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Totem/Body Small Bold — 14 SemiBold 150%
  static final bodySmallBold = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// Totem/Caption — 12 Regular 150%
  static final caption = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Totem/Caption Medium — 12 Medium 150%
  static final captionMedium = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Totem/Caption Bold — 12 SemiBold 150%
  static final captionBold = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// Totem/Overline — 10 Medium 150%
  static final overline = _base.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Totem/Overline Bold — 10 SemiBold 150% / +12px tracking
  static final overlineBold = _base.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 12,
  );

  /// Totem/Button Large — 18 SemiBold 120%
  static final buttonLarge = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Totem/Button — 16 SemiBold 120%
  static final button = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Totem/Button Small — 14 SemiBold 120%
  static final buttonSmall = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Totem/Numeric Large — 32 Bold 110%
  static final numericLarge = _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  /// Totem/Numeric — 24 Bold 110%
  static final numeric = _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  /// Totem/Numeric Small — 18 SemiBold 110%
  static final numericSmall = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  // Legacy styles still bound on Video Experience frames

  /// Heading 1 — same as Totem/Display
  static final heading1 = display;

  /// Heading 2 — same as Totem/H1
  static final heading2 = h1;

  /// Heading 3 — same as Totem/H2
  static final heading3 = h2;

  /// Body 1 — 16 Regular 120% (tighter than Totem/Body)
  static final body1 = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// Body 2 — 12 Regular 120%
  static final body2 = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// Body 3 — 9 Regular 120%
  static final body3 = _base.copyWith(
    fontSize: 9,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// Ad-hoc Montserrat style for one-off Figma values that aren't on the ramp.
  static TextStyle raw({
    required double size,
    FontWeight weight = FontWeight.w400,
    double height = 1.2,
    Color? color,
    double letterSpacing = 0,
  }) {
    return _base.copyWith(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
