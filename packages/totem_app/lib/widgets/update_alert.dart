import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/update_available_dialog.dart';
import 'package:upgrader/upgrader.dart';

class TotemUpgradeAlert extends UpgradeAlert {
  TotemUpgradeAlert({
    super.key,
    required Widget child,
    super.navigatorKey,
    @visibleForTesting Upgrader? upgrader,
  }) : super(
         child: child,
         // UpgradeAlertState only initializes the upgrader in initState, so
         // every rebuild of this widget must hand it the same instance.
         upgrader: upgrader ?? _sharedUpgrader,
         // Release notes stay out of the Totem-designed dialog for now.
         showReleaseNotes: false,
       );

  static final _sharedUpgrader = _MinorVersionUpgrader();

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
  /// Whether the open dialog was closed by one of its buttons, as opposed to
  /// being removed by the router replacing the page underneath it.
  bool _closedByUser = false;

  @override
  void checkVersion({required BuildContext context}) {
    final navigatorKey = widget.navigatorKey;
    if (navigatorKey == null) return super.checkVersion(context: context);

    // The builder context sits above the router's Navigator, so wait for the
    // Navigator to mount rather than falling back to it.
    final navigatorContext = navigatorKey.currentContext;
    if (navigatorContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    super.checkVersion(context: navigatorContext);
  }

  @override
  void showTheDialog({
    Key? key,
    required BuildContext context,
    required String? title,
    required String message,
    required String? releaseNotes,
    required bool barrierDismissible,
    required UpgraderMessages messages,
  }) {
    if (!context.mounted) {
      displayed = false;
      return;
    }

    widget.upgrader.saveLastAlerted();
    _closedByUser = false;

    showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => PopScope(
        canPop: onCanPop(),
        child: alertDialog(
          key,
          title ?? '',
          message,
          releaseNotes,
          dialogContext,
          false,
          messages,
        ),
      ),
    ).then((_) {
      if (!mounted || _closedByUser) return;
      // The dialog is a pageless route, so GoRouter drops it when it replaces
      // the page below (e.g. the splash redirect). Show it again on the new
      // page instead of losing it until the next alert interval.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigatorContext = widget.navigatorKey?.currentContext;
        if (navigatorContext == null) {
          displayed = false;
          return;
        }
        showTheDialog(
          key: key,
          context: navigatorContext,
          title: title,
          message: message,
          releaseNotes: releaseNotes,
          barrierDismissible: barrierDismissible,
          messages: messages,
        );
      });
    });
  }

  @override
  void popNavigator(BuildContext context) {
    _closedByUser = true;
    super.popNavigator(context);
  }

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
    final isBlocked = widget.upgrader.blocked();
    final showIgnore = isBlocked ? false : widget.showIgnore;
    final showLater = isBlocked ? false : widget.showLater;
    final updateButton =
        messages.message(UpgraderMessage.buttonTitleUpdate) ?? 'Update';
    final laterButton =
        messages.message(UpgraderMessage.buttonTitleLater) ?? 'Later';
    final ignoreButton =
        messages.message(UpgraderMessage.buttonTitleIgnore) ?? 'Ignore';
    final prompt = widget.showPrompt
        ? messages.message(UpgraderMessage.prompt)
        : null;

    return UpdateAvailableDialog(
      key: key,
      title: title,
      message: message,
      prompt: prompt,
      updateButtonText: updateButton,
      onUpdate: () => onUserUpdated(context, !isBlocked),
      laterButtonText: showLater ? laterButton : null,
      onLater: showLater ? () => onUserLater(context, true) : null,
      ignoreButtonText: showIgnore ? ignoreButton : null,
      onIgnore: showIgnore ? () => onUserIgnored(context, true) : null,
    );
  }
}
