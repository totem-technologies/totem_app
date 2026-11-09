import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

class ForcePassConfirmationDialog extends StatelessWidget {
  const ForcePassConfirmationDialog({
    required this.session,
    required this.nextParticipantName,
    super.key,
  });

  final SessionController session;
  final String? nextParticipantName;

  @override
  Widget build(BuildContext context) {
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
      onConfirm: () async {
        try {
          await session.keeper.forcePassTotem();
        } catch (error) {
          if (context.mounted) {
            ErrorHandler.showErrorSnackBar(
              context,
              'Failed to perform next totem action',
            );
          }
        } finally {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
    );
  }
}
