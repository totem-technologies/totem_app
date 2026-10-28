import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/totem_dialog_layout.dart';

/// Dialog shown when a newer store version of the mobile app is available.
///
/// Shares [TotemDialogLayout] with ConfirmationDialog but not its buttons:
/// ConfirmationDialog's Cancel / async busy handlers pop the route themselves,
/// while upgrader's `onUser*` callbacks also pop — reusing them would
/// double-pop. Used by the mobile upgrader integration in totem_app;
/// previewed in Widgetbook under Components/Dialogs.
class UpdateAvailableDialog extends StatelessWidget {
  const UpdateAvailableDialog({
    required this.title,
    required this.message,
    required this.updateButtonText,
    required this.onUpdate,
    this.prompt,
    this.laterButtonText,
    this.onLater,
    this.ignoreButtonText,
    this.onIgnore,
    this.icon = TotemIcons.downloadApp,
    this.iconSize = 60,
    super.key,
  });

  final String title;
  final String message;

  /// Optional third line under [message] (e.g. upgrader's prompt).
  final String? prompt;

  final String updateButtonText;
  final VoidCallback onUpdate;

  /// When both [laterButtonText] and [onLater] are set, shows a secondary
  /// outlined dismiss action (hidden for force-update / blocked upgrades).
  final String? laterButtonText;
  final VoidCallback? onLater;

  /// Optional tertiary text action to ignore this version.
  final String? ignoreButtonText;
  final VoidCallback? onIgnore;

  final TotemIconData? icon;
  final double iconSize;

  bool get _showLater => laterButtonText != null && onLater != null;
  bool get _showIgnore => ignoreButtonText != null && onIgnore != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaledIconSize = MediaQuery.textScalerOf(context).scale(iconSize);
    final bodyStyle = TextStyle(color: theme.colorScheme.onSurface);

    return TotemDialogLayout(
      bodyMaxHeight: 400,
      // downloadApp (and similar) SVGs ship their own fills.
      icon: icon == null
          ? null
          : TotemIcon(icon!, size: scaledIconSize, fillColor: false),
      title: title,
      body: [
        Text(message, textAlign: TextAlign.center, style: bodyStyle),
        if (prompt case final prompt?)
          Text(prompt, textAlign: TextAlign.center, style: bodyStyle),
      ],
      actions: [
        ElevatedButton(
          autofocus: true,
          onPressed: onUpdate,
          child: Text(updateButtonText, textAlign: TextAlign.center),
        ),
        if (_showLater)
          OutlinedButton(
            onPressed: onLater,
            child: Text(laterButtonText!, textAlign: TextAlign.center),
          ),
        if (_showIgnore)
          TextButton(
            onPressed: onIgnore,
            child: Text(ignoreButtonText!, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}
