import 'package:material_ui/material_ui.dart';

import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

/// Builds the live level indicator shown in the microphone button while the
/// microphone is on.
typedef MicrophoneLevelBuilder =
    Widget Function(Color color, double iconSize, int barCount);

class ActionBarMicButton extends StatefulWidget {
  const ActionBarMicButton({
    required this.isMicOn,
    required this.onToggle,
    this.microphoneLevel,
    this.requiresUnmuteConfirmation = false,
    this.indicatorColor,
    this.indicatorBarCount = 5,
    super.key,
  });

  final bool isMicOn;
  final ActionBarButtonToggleCallback? onToggle;

  /// The level indicator shown while the microphone is on. Without one, the
  /// button shows a plain microphone icon.
  final MicrophoneLevelBuilder? microphoneLevel;

  final bool requiresUnmuteConfirmation;
  final Color? indicatorColor;
  final int indicatorBarCount;

  @override
  State<ActionBarMicButton> createState() => _ActionBarMicButtonState();
}

class _ActionBarMicButtonState extends State<ActionBarMicButton> {
  bool _busy = false;

  Future<void> _toggleMicrophone() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final shouldEnable = !widget.isMicOn;
      if (shouldEnable && widget.requiresUnmuteConfirmation) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => ConfirmationDialog(
            content:
                'Someone else has the Totem.\n'
                'Are you sure you want to unmute?',
            confirmButtonText: 'Unmute Anyway',
            type: ConfirmationDialogType.standard,
            showCancel: false,
            onConfirm: () async => Navigator.of(dialogContext).pop(true),
            extraButtons: [
              ConfirmationDialogButton.outlined(
                onConfirm: () async => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay Muted'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      await widget.onToggle?.call(shouldEnable);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.isMicOn;

    return ActionBarButton(
      semanticsLabel: 'Microphone ${isEnabled ? 'on' : 'off'}',
      role: ActionBarButtonRole.media(enabled: isEnabled),
      onPressed: _busy ? null : _toggleMicrophone,
      child: isEnabled
          ? Builder(
              builder: (context) {
                final microphoneLevel = widget.microphoneLevel;
                if (microphoneLevel == null) {
                  return const TotemIcon(TotemIcons.microphoneOn);
                }
                return microphoneLevel(
                  // Follow the action-bar ghost color so prejoin cream-on-cream
                  // doesn't eat the bars.
                  widget.indicatorColor ??
                      IconTheme.of(context).color ??
                      AppTheme.cream,
                  IconTheme.of(context).size ?? 20,
                  widget.indicatorBarCount,
                );
              },
            )
          : const TotemIcon(TotemIcons.microphoneOff),
    );
  }
}
