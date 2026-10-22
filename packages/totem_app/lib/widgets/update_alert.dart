import 'package:material_ui/material_ui.dart';
import 'package:upgrader/upgrader.dart';

class TotemUpgradeAlert extends UpgradeAlert {
  TotemUpgradeAlert({super.key, required Widget child})
    : super(child: child, upgrader: _MinorVersionUpgrader());

  @override
  UpgradeAlertState createState() => _TotemUpgradeAlertState();
}

// Totem treats changes to the second version component as release updates,
// including after the app reaches version 1.0.0.
class _MinorVersionUpgrader extends Upgrader {
  @override
  bool shouldDisplayUpgrade() {
    if (blocked()) return super.shouldDisplayUpgrade();
    return hasMinorVersionUpdate(
          currentInstalledVersion,
          currentAppStoreVersion,
        ) &&
        super.shouldDisplayUpgrade();
  }
}

bool hasMinorVersionUpdate(String? installedVersion, String? storeVersion) {
  final installedMinor = _minorVersion(installedVersion);
  final storeMinor = _minorVersion(storeVersion);
  return installedMinor != null &&
      storeMinor != null &&
      installedMinor != storeMinor;
}

int? _minorVersion(String? version) {
  if (version == null) return null;
  final components = version.split('.');
  if (components.length < 2) return null;
  return int.tryParse(components[1]);
}

class _TotemUpgradeAlertState extends UpgradeAlertState {
  @override
  Widget alertDialog(
    Key? key,
    String title,
    String message,
    String? releaseNotes,
    BuildContext context,
    bool cupertino,
    UpgraderMessages messages,
  ) {
    final theme = Theme.of(context);
    final isBlocked = widget.upgrader.blocked();
    final showIgnore = isBlocked ? false : widget.showIgnore;
    final showLater = isBlocked ? false : widget.showLater;
    final updateButton =
        messages.message(UpgraderMessage.buttonTitleUpdate) ?? '';
    final laterButton =
        messages.message(UpgraderMessage.buttonTitleLater) ?? '';
    final ignoreButton =
        messages.message(UpgraderMessage.buttonTitleIgnore) ?? '';
    final prompt = messages.message(UpgraderMessage.prompt) ?? '';

    return AlertDialog(
      key: key,
      constraints: const BoxConstraints(maxWidth: 480),
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 24,
        vertical: 28,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style:
                          (theme.dialogTheme.titleTextStyle ??
                                  theme.textTheme.titleLarge)
                              ?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontSize: 18,
                              ),
                    ),
                  ),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  if (widget.showPrompt)
                    Text(
                      prompt,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              ElevatedButton(
                autofocus: true,
                onPressed: () => onUserUpdated(context, !isBlocked),
                child: Text(updateButton),
              ),
              if (showLater)
                OutlinedButton(
                  onPressed: () => onUserLater(context, true),
                  child: Text(laterButton),
                ),
              if (showIgnore)
                TextButton(
                  onPressed: () => onUserIgnored(context, true),
                  child: Text(ignoreButton),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
