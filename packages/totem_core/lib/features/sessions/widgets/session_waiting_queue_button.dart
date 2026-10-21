import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

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
    return Material(
      color: const Color(0xFFE8C576),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Semantics(
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text(
              label ??
                  (count == 1 ? '1 person waiting' : '$count people waiting'),
              style: entryBody.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
