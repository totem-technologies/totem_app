import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/policy.dart';
import 'package:totem_core/features/permissions/ui/recovery_content.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

/// Turns a device on at the user's request, asking for permission first
/// where the platform needs it, and explaining what to do when it can't work.
///
/// Pre-join and the session both use this, so the decision is made the same
/// way in both (X6, X7, X13). Pass [explain] false where the screen already
/// shows the device's fix, such as the pre-join microphone banner.
Future<void> turnOnMedia(
  BuildContext context,
  WidgetRef ref,
  MediaControl control, {
  bool explain = true,
}) async {
  final permissions = ref.read(mediaPermissionControllerProvider.notifier);
  final needsHelp = await _attemptTurnOn(permissions, control);
  if (needsHelp && explain && context.mounted) {
    await showMediaRecoveryDialog(context, control);
  }
}

/// Follows [userCaptureStep] and returns whether the user now needs help:
/// decided from the actual outcome, not a guess made before it lands.
Future<bool> _attemptTurnOn(
  MediaPermissionController permissions,
  MediaControl control,
) async {
  final kind = control.kind;
  final platform = permissions.platform;
  switch (userCaptureStep(permissions.permissionOf(kind), platform)) {
    case UserCaptureStep.recover:
      return true;
    case UserCaptureStep.requestFirst:
      final result = await permissions.request(kind);
      if (result != MediaPermission.granted) {
        return explainsRefusal(result, platform);
      }
    case UserCaptureStep.capture:
      break;
  }
  return switch (await control.turnOn()) {
    TurnedOn() || TurnOnSkipped() => false,
    TurnOnFailed(:final failure) => needsAttention(
      permissions.permissionOf(kind),
      failure.problem,
      platform,
    ),
  };
}

/// Runs a device's recovery action directly where there is one, and shows
/// its help otherwise. [explain] is as for [turnOnMedia].
Future<void> recoverMedia(
  BuildContext context,
  WidgetRef ref,
  MediaControl control, {
  bool explain = true,
}) async {
  final permissions = ref.read(mediaPermissionControllerProvider.notifier);
  final action = recoveryFor(
    permissions.permissionOf(control.kind),
    ref.read(control.problem),
    permissions.platform,
  );
  switch (action) {
    case RecoveryAction.none:
      return;
    // Asking and retrying both capture, and say why if it fails again.
    case RecoveryAction.request || RecoveryAction.retry:
      await turnOnMedia(context, ref, control, explain: explain);
    case RecoveryAction.openAppSettings:
      await permissions.openSettings();
    // The dialog's copy button confirms the copy.
    case RecoveryAction.openInBrowser ||
        RecoveryAction.showBrowserSiteSettings ||
        RecoveryAction.showSystemPrivacySettings ||
        RecoveryAction.explainRestricted ||
        RecoveryAction.explainUnsupported:
      if (context.mounted) await showMediaRecoveryDialog(context, control);
  }
}

Future<void> _copyPageLink() =>
    Clipboard.setData(ClipboardData(text: Uri.base.toString()));

Future<void> showMediaRecoveryDialog(
  BuildContext context,
  MediaControl control,
) => showDialog<void>(
  context: context,
  builder: (_) => MediaRecoveryDialog(control: control),
);

/// The full help for one device: why it isn't working and how to fix it.
///
/// Follows the device's permission and problem: it closes once there's
/// nothing left to fix, and shows any new problem in place instead of
/// opening another dialog. While an action started here runs, it stays open
/// so the action's outcome can be shown.
class MediaRecoveryDialog extends ConsumerStatefulWidget {
  const MediaRecoveryDialog({required this.control, super.key});

  final MediaControl control;

  @override
  ConsumerState<MediaRecoveryDialog> createState() =>
      _MediaRecoveryDialogState();
}

class _MediaRecoveryDialogState extends ConsumerState<MediaRecoveryDialog> {
  bool _acting = false;

  MediaControl get _control => widget.control;

  RecoveryAction _currentAction() => recoveryFor(
    ref.read(mediaPermissionControllerProvider)?[_control.kind] ??
        MediaPermission.unknown,
    ref.read(_control.problem),
    ref.read(platformInfoProvider),
  );

  /// Closes this dialog, never a route someone opened on top of it.
  void _closeIfFixed() {
    if (_acting || !mounted || _currentAction() != RecoveryAction.none) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _acting = false);
        _closeIfFixed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = _control.kind;
    final permission =
        ref.watch(mediaPermissionControllerProvider)?[kind] ??
        MediaPermission.unknown;
    final problem = ref.watch(_control.problem);
    final content = recoveryContent(
      kind,
      permission,
      problem,
      ref.watch(platformInfoProvider),
    );
    final theme = Theme.of(context);

    // Fixed elsewhere, such as in Settings or site settings (X5).
    ref
      ..listen(mediaPermissionControllerProvider, (_, _) => _closeIfFixed())
      ..listen(_control.problem, (_, _) => _closeIfFixed());

    final checkAgain = content.canCheckAgain
        ? () => unawaited(_act(() => _control.turnOn()))
        : null;
    final primary =
        _primaryAction(content) ??
        (checkAgain == null
            ? null
            : ElevatedButton(
                onPressed: _acting ? null : checkAgain,
                child: const Text('Check again'),
              ));
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      title: Text(content.title, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Text(content.message, textAlign: TextAlign.center),
              for (final section in content.sections)
                RecoverySectionView(section: section),
              if (content.helper case final helper?)
                Text(
                  helper,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
      // The fix is the one prominent action; closing is secondary.
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              ?primary,
              // Both offered when the content has its own primary action.
              if (checkAgain != null && content.actionLabel != null)
                OutlinedButton(
                  onPressed: _acting ? null : checkAgain,
                  child: const Text('Check again'),
                ),
              // The app's modal button, the same as every dialog's Cancel.
              ConfirmationDialogButton.outlined(
                onConfirm: () async => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _primaryAction(RecoveryContent content) {
    final label = content.actionLabel;
    if (label == null) return null;
    if (content.action == RecoveryAction.openInBrowser) {
      return _CopyLinkButton(label: label);
    }
    final permissions = ref.read(mediaPermissionControllerProvider.notifier);
    final VoidCallback onPressed = switch (content.action) {
      RecoveryAction.openAppSettings => () => unawaited(
        permissions.openSettings(),
      ),
      _ => () => unawaited(_act(() => _attemptTurnOn(permissions, _control))),
    };
    return ElevatedButton(
      onPressed: _acting ? null : onPressed,
      child: Text(label),
    );
  }
}

class RecoverySectionView extends StatelessWidget {
  const RecoverySectionView({required this.section, super.key});

  final RecoverySection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (section.heading case final heading?)
          Text(
            heading,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        for (final (index, step) in section.steps.indexed)
          Row(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Text(step)),
            ],
          ),
      ],
    );
  }
}

/// Copies the page link for opening in a real browser (WS5), and says so
/// for a moment, since copying shows nothing by itself.
class _CopyLinkButton extends StatefulWidget {
  const _CopyLinkButton({required this.label});

  final String label;

  @override
  State<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<_CopyLinkButton> {
  Timer? _reset;

  Future<void> _copy() async {
    await _copyPageLink();
    if (!mounted) return;
    _reset?.cancel();
    setState(() {
      _reset = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _reset = null);
      });
    });
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: () => unawaited(_copy()),
    child: Text(
      _reset == null ? widget.label : 'Link copied. Paste it in your browser.',
    ),
  );
}

/// A compact notice for a device that can't be used, with its fix.
///
/// Renders nothing while there's nothing to fix.
class MediaRecoveryBanner extends ConsumerWidget {
  const MediaRecoveryBanner({required this.control, super.key});

  final MediaControl control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = recoveryContent(
      control.kind,
      ref.watch(mediaPermissionControllerProvider)?[control.kind] ??
          MediaPermission.unknown,
      ref.watch(control.problem),
      ref.watch(platformInfoProvider),
    );
    if (content.action == RecoveryAction.none) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 366),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(content.message, textAlign: TextAlign.center),
          if (content.action == RecoveryAction.openInBrowser)
            _CopyLinkButton(label: content.actionLabel ?? 'Copy link')
          else
            ElevatedButton(
              // The banner updates to the new state on its own.
              onPressed: () => unawaited(
                recoverMedia(context, ref, control, explain: false),
              ),
              // Restricted and unsupported devices have nothing to do here,
              // only an explanation.
              child: Text(content.actionLabel ?? 'Learn more'),
            ),
        ],
      ),
    );
  }
}
