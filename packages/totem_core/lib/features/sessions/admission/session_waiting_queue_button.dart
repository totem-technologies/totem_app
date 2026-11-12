import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/session_button_style.dart';

/// Keeper's queue indicator. The host supplies the current waiting count and
/// opens the admission surface; this control never owns the queue.
class SessionWaitingQueueButton extends StatelessWidget {
  const SessionWaitingQueueButton({
    required this.count,
    super.key,
    this.label,
    this.onPressed,
  });

  final int count;
  final String? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && label == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: SessionButtonStyle.outlined(
        compact: true,
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.slate,
        side: BorderSide(color: AppTheme.slate.withValues(alpha: 0.2)),
        // A status chip rather than an action, so it stays a pill.
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.people_outline, size: 20),
      label: Text(
        label ?? (count == 1 ? '1 person waiting' : '$count people waiting'),
      ),
    );
  }
}
