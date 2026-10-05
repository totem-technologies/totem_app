import 'dart:ui';

/// Totem/Colors + leftover "Variable collection" entries.
///
/// One constant per Figma variable. Hex lives here and nowhere else.
///
/// Mapping (Figma name → Dart):
///   Variable collection / Slate          → [TotemColors.slate]
///   Totem/Colors / Core/Slate            → [TotemColors.coreSlate]
///   Totem/Colors / Core/Mauve            → [TotemColors.coreMauve]
///   Totem/Colors / Core/Cream            → [TotemColors.coreCream]
///   Totem/Colors / Core/White            → [TotemColors.coreWhite]
///   Totem/Colors / Core/Gray             → [TotemColors.coreGray]
///   Totem/Colors / Extended/Gold         → [TotemColors.extendedGold]
///   Totem/Colors / Extended/Sky          → [TotemColors.extendedSky]
///   Totem/Colors / Extended/Rose         → [TotemColors.extendedRose]
///   Totem/Colors / Extended/Steel        → [TotemColors.extendedSteel]
///   Totem/Colors / Extended/Berry        → [TotemColors.extendedBerry]
///   Totem/Colors / Semantic/Error        → [TotemColors.semanticError]
///   Totem/Colors / Semantic/Success      → [TotemColors.semanticSuccess]
///   Totem/Colors / Overlay/Slate-60      → [TotemColors.overlaySlate60]
///   Totem/Colors / Overlay/Slate-70      → [TotemColors.overlaySlate70]
///   Totem/Colors / Overlay/White-08      → [TotemColors.overlayWhite08]
///   Totem/Colors / Overlay/White-16      → [TotemColors.overlayWhite16]
///
/// Not a color — skipped:
///   Variable collection / String = "Next Session: Letting Shame Fall Away"
///
/// Spec-frame mismatch:
///   Design System Spec labels White as #FFFFF8. The bound variable is #ffffff.
///   We follow the variable. Swap here if the spec label is the source of truth.
abstract final class TotemColors {
  // Primitive / core
  static const slate = Color(0xFF262F37);
  static const coreSlate = Color(0xFF262F37);
  static const coreMauve = Color(0xFF987AA5);
  static const coreCream = Color(0xFFF3F1E9);
  static const coreWhite = Color(0xFFFFFFFF);
  static const coreGray = Color(0xFF787D7E);

  // Extended
  static const extendedGold = Color(0xFFF4DC92);
  static const extendedSky = Color(0xFF9BC0DD);
  static const extendedRose = Color(0xFFD999AA);
  static const extendedSteel = Color(0xFF55778F);
  static const extendedBerry = Color(0xFF8B5363);

  // Semantic
  static const semanticError = Color(0xFFFF545C);
  static const semanticSuccess = Color(0xFF98BD44);

  // Overlays (alpha baked in by Figma)
  static const overlaySlate60 = Color(0x99262F37);
  static const overlaySlate70 = Color(0xB2262F37);
  static const overlayWhite08 = Color(0x14FFFFFF);
  static const overlayWhite16 = Color(0x29FFFFFF);

  /// Unmapped: Miscellaneous/Keyboard Accessory Bar - Selection. Showed up on
  /// the Video Experience node, but it is not a local Totem variable.
  static const iosKeyboardAccessorySelection = Color(0xFFEBEDF0);
}
