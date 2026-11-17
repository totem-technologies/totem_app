import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';

/// Typography and proportions for text buttons in the session UI.
///
/// | Role     | Height | Label        | Use                                   |
/// |----------|--------|--------------|---------------------------------------|
/// | hero     | 52     | 21 / w600    | Join (pill)                           |
/// | standard | 52     | 16 / w600    | dialog, sheet and screen actions      |
/// | compact  | 40     | 14 / w600    | actions inside list rows and headers  |
///
/// Standard and compact buttons share a 20dp corner radius; filled and
/// outlined variants only differ in color, so a primary / secondary pair
/// keeps the same size.
abstract final class SessionButtonStyle {
  static const double heroHeight = 52;
  static const double height = 52;
  static const double compactHeight = 40;

  static const BorderRadius radius = BorderRadius.all(Radius.circular(20));

  static const EdgeInsetsGeometry padding = EdgeInsetsDirectional.symmetric(
    horizontal: 16,
  );
  static const EdgeInsetsGeometry compactPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 14);

  // A button's text style replaces the theme's rather than merging with it,
  // so each label names the app font explicitly.
  static const TextStyle heroLabel = TextStyle(
    fontFamily: AppTheme.fontFamilySans,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );
  static const TextStyle label = TextStyle(
    fontFamily: AppTheme.fontFamilySans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );
  static const TextStyle compactLabel = TextStyle(
    fontFamily: AppTheme.fontFamilySans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );

  // Colors are parameters rather than merged in afterwards: `styleFrom`
  // always sets a text style property, so merging another `styleFrom` result
  // over these would drop the label style.

  /// Primary action. Colors come from the theme unless overridden.
  static ButtonStyle filled({
    bool compact = false,
    Color? backgroundColor,
    Color? foregroundColor,
    Size? maximumSize,
  }) => ElevatedButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    maximumSize: maximumSize,
    textStyle: compact ? compactLabel : label,
    padding: compact ? compactPadding : padding,
    minimumSize: _minimumSize(compact),
    shape: const RoundedRectangleBorder(borderRadius: radius),
  );

  /// Secondary action, sized like [filled].
  static ButtonStyle outlined({
    bool compact = false,
    Color? backgroundColor,
    Color? foregroundColor,
    BorderSide? side,
    OutlinedBorder shape = const RoundedRectangleBorder(borderRadius: radius),
  }) => OutlinedButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    side: side,
    textStyle: compact ? compactLabel : label,
    padding: compact ? compactPadding : padding,
    minimumSize: _minimumSize(compact),
    shape: shape,
  );

  static Size _minimumSize(bool compact) =>
      compact ? const Size(64, compactHeight) : const Size(20, height);
}
