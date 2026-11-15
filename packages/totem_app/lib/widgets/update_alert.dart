import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/app_config.dart';
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
         // Later already re-prompts after a few days; skipping a release for
         // good is not offered.
         showIgnore: false,
       );

  static final _sharedUpgrader = _EnvironmentUpgrader(
    messages: TotemUpgraderMessages(),
  );

  @override
  UpgradeAlertState createState() => _TotemUpgradeAlertState();
}

class TotemUpgraderMessages extends UpgraderMessages {
  @override
  String? message(UpgraderMessage messageKey) => switch (messageKey) {
    UpgraderMessage.title => 'Update available',
    UpgraderMessage.body =>
      'A newer version of Totem is available. Update to get the latest '
          'fixes and improvements.',
    UpgraderMessage.prompt => 'Would you like to update now?',
    UpgraderMessage.buttonTitleUpdate => 'Update',
    UpgraderMessage.buttonTitleLater => 'Later',
    _ => super.message(messageKey),
  };
}

class _EnvironmentUpgrader extends Upgrader {
  _EnvironmentUpgrader({super.messages});
  @override
  bool shouldDisplayUpgrade() {
    if (blocked()) return super.shouldDisplayUpgrade();
    return hasVersionUpdate(
          currentInstalledVersion,
          currentAppStoreVersion,
          AppConfig.instance.environment,
        ) &&
        super.shouldDisplayUpgrade();
  }
}

@visibleForTesting
bool hasVersionUpdate(
  String? installedVersion,
  String? storeVersion,
  Environment environment,
) {
  final componentCount = switch (environment) {
    Environment.production => 1,
    Environment.development => 2,
    Environment.staging => 3,
  };
  final installed = _versionComponents(installedVersion, componentCount);
  final store = _versionComponents(storeVersion, componentCount);
  if (installed == null || store == null) return false;
  for (var i = 0; i < componentCount; i++) {
    if (installed[i] != store[i]) return true;
  }
  return false;
}

List<int>? _versionComponents(String? version, int count) {
  if (version == null) return null;
  final components = version.split('.');
  if (components.length < count) return null;
  final result = <int>[];
  for (final component in components.take(count)) {
    final value = int.tryParse(component);
    if (value == null) return null;
    result.add(value);
  }
  return result;
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
      // Any close other than the dialog's own buttons reaches this path,
      // including a Navigator pop or barrier tap. Today back is blocked and
      // barrierDismissible is false, so this means GoRouter replaced the page
      // below the pageless route. Re-show it on the new page rather than
      // losing the alert until the next interval; keep barrier dismissal off
      // unless that behavior is intentionally changed.
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
    final showLater = isBlocked ? false : widget.showLater;
    final updateButton =
        messages.message(UpgraderMessage.buttonTitleUpdate) ?? 'Update';
    final laterButton =
        messages.message(UpgraderMessage.buttonTitleLater) ?? 'Later';
    final prompt = widget.showPrompt
        ? messages.message(UpgraderMessage.prompt)
        : null;
    final dialogTitle = messages.message(UpgraderMessage.title) ?? title;
    final dialogMessage = messages.message(UpgraderMessage.body) ?? message;

    return UpdateAvailableDialog(
      key: key,
      title: dialogTitle,
      message: dialogMessage,
      prompt: prompt,
      updateButtonText: updateButton,
      onUpdate: () => onUserUpdated(context, !isBlocked),
      laterButtonText: showLater ? laterButton : null,
      onLater: showLater ? () => onUserLater(context, true) : null,
    );
  }
}
