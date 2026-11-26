import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/presentation/session_action_feedback.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

class ForcePassConfirmationDialog extends ConsumerWidget {
  const ForcePassConfirmationDialog({
    required this.session,
    required this.nextParticipantName,
    super.key,
  });

  final SessionController session;
  final String? nextParticipantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ConfirmationDialog(
      title: 'Are you sure?',
      confirmButtonText: 'Force pass',
      content:
          "This will end the current speaker's turn and give the totem to ${nextParticipantName ?? 'the next participant'}.",
      contentStyle: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      type: ConfirmationDialogType.standard,
      // The turn service owns the deadline and reports a timeout as unknown.
      actionTimeout: null,
      onConfirm: () async {
        final feedback = ref.read(sessionActionFeedbackProvider.notifier);
        final turnBefore = feedback.turnSnapshot();
        try {
          await session.keeper.forcePassTotem();
        } catch (error, stackTrace) {
          final applied = feedback.turnAppliedDespite(
            error,
            turnBefore,
            action: SessionAction.forcePass,
          );
          if (!applied) {
            feedback.report(
              SessionAction.forcePass,
              error,
              subject: nextParticipantName,
              stackTrace: stackTrace,
            );
          }
          // Close on success, on an unconfirmed request, or when room state
          // already shows the pass, so a retry cannot skip the next person.
          final unknown =
              SessionCommandFailure.from(error).kind ==
              SessionCommandFailureKind.unknownOutcome;
          if (!applied && !unknown) return;
        }
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}
