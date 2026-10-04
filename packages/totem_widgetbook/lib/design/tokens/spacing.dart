/// Totem/Spacing — float variables, in logical pixels.
///
/// Mapping:
///   spacing/4  → [Spacing.s4]
///   spacing/8  → [Spacing.s8]
///   spacing/12 → [Spacing.s12]
///   spacing/16 → [Spacing.s16]
///   spacing/20 → [Spacing.s20]
///   spacing/24 → [Spacing.s24]
///   spacing/32 → [Spacing.s32]
///   spacing/40 → [Spacing.s40]
///   spacing/48 → [Spacing.s48]
///   spacing/64 → [Spacing.s64]
///
/// Unmapped node leftovers:
///   homebar/width = 154  → [Spacing.homebarWidth]
abstract final class Spacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  /// Unmapped: homebar/width
  static const homebarWidth = 154.0;
}

/// Totem/Radius
///
/// Mapping:
///   radius/sm   → [Radii.sm]    (6)
///   radius/md   → [Radii.md]    (12)
///   radius/lg   → [Radii.lg]    (20)
///   radius/full → [Radii.full]  (999)
abstract final class Radii {
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const full = 999.0;
}
