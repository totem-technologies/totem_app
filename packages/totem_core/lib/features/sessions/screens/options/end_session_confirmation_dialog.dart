import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/screens/options/session_actions.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

class EndSessionConfirmationDialog extends StatelessWidget {
  const EndSessionConfirmationDialog({required this.session, super.key});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return ConfirmationDialog(
      title: 'End session',
      content: 'Are you sure you want to end the session?',
      confirmButtonText: 'End session',
      onConfirm: () async {
        await endSessionWithErrorHandling(context, session);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}
