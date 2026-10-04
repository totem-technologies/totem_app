import 'package:material_ui/material_ui.dart';

import '../paint.dart';
import 'colors.dart';
import 'typography.dart';

/// Theme aliases used by the Gallery chrome and the screen shells.
///
/// Figma has a single mode — dark is composed from core tokens.
@immutable
class TotemTheme extends ThemeExtension<TotemTheme> {
  const TotemTheme({
    required this.canvas,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.accent,
    required this.border,
  });

  static final light = TotemTheme(
    canvas: TotemColors.coreCream,
    surface: TotemColors.coreWhite,
    textPrimary: TotemColors.coreSlate,
    textSecondary: TotemColors.coreGray,
    textOnAccent: TotemColors.coreWhite,
    accent: TotemColors.coreMauve,
    // Unmapped: gallery hairline — no Figma border token.
    border: fade(TotemColors.coreSlate, 0.12),
  );

  static final dark = TotemTheme(
    canvas: TotemColors.coreSlate,
    // Unmapped: Overlay/White-08 composited onto Core/Slate — Figma has no
    // dark surface token.
    surface: mix(TotemColors.coreWhite, 0.08, TotemColors.coreSlate),
    textPrimary: TotemColors.coreCream,
    textSecondary: TotemColors.coreGray,
    textOnAccent: TotemColors.coreWhite,
    accent: TotemColors.coreMauve,
    border: TotemColors.overlayWhite16,
  );

  final Color canvas;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnAccent;
  final Color accent;
  final Color border;

  static TotemTheme of(BuildContext context) =>
      Theme.of(context).extension<TotemTheme>() ?? light;

  /// Material theme carrying Montserrat and these aliases.
  static ThemeData themeData(Brightness brightness) {
    final tokens = brightness == Brightness.dark ? dark : light;
    return ThemeData(
      brightness: brightness,
      fontFamily: TotemText.fontFamily,
      scaffoldBackgroundColor: tokens.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TotemColors.coreMauve,
        brightness: brightness,
        surface: tokens.surface,
      ),
      splashFactory: NoSplash.splashFactory,
      extensions: [tokens],
    );
  }

  @override
  TotemTheme copyWith({
    Color? canvas,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnAccent,
    Color? accent,
    Color? border,
  }) {
    return TotemTheme(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accent: accent ?? this.accent,
      border: border ?? this.border,
    );
  }

  @override
  TotemTheme lerp(TotemTheme? other, double t) {
    if (other == null) return this;
    return TotemTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
