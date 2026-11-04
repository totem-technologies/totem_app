import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';

/// Glass pill shared by `SessionActionBar` and the docked transition cards,
/// so the pass/receive controls read as part of the bottom dock.
BoxDecoration sessionDockDecoration({required bool onLightBackground}) {
  // 8% white glass disappears on the waiting-room cream gradient.
  final fill = onLightBackground
      ? AppTheme.slate.withValues(alpha: 0.12)
      : AppTheme.white.withValues(alpha: 0.08);
  final stroke = onLightBackground
      ? AppTheme.slate.withValues(alpha: 0.22)
      : AppTheme.white.withValues(alpha: 0.16);

  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: stroke, width: 1.5),
  );
}
