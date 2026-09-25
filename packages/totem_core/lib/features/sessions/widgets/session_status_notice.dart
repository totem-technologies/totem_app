import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';

/// A prominent, two-line status notice used while the room is waiting.
///
/// Renders a steady dot with a small uppercase [label] above a larger,
/// semi-bold [message] so the status is easy to notice at a glance. The
/// treatment mirrors the session title so it reads the same on mobile and
/// desktop.
class SessionStatusNotice extends StatelessWidget {
  const SessionStatusNotice({
    required this.label,
    required this.message,
    super.key,
  });

  /// Short uppercase eyebrow, e.g. `STARTING SOON`.
  final String label;

  /// The status message itself.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppTheme.mauve,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.messageChipText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        Text(
          message,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
