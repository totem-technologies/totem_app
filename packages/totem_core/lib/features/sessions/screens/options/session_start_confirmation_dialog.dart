import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

/// Confirms starting with the live admission queue before changing room state.
class SessionStartConfirmationDialog extends StatelessWidget {
  const SessionStartConfirmationDialog({required this.onStart, super.key});

  final Future<bool> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final admission = SessionAdmissionScope.maybeOf(context);
    final count = admission?.requests.length ?? 0;

    Future<void> start() async {
      final success = await onStart();
      if (success && context.mounted) Navigator.of(context).pop();
    }

    return ConfirmationDialog(
      title: 'Start session',
      content: count == 0
          ? 'Are you sure you want to start the session?'
          : 'You have $count ${count == 1 ? 'participant' : 'participants'} waiting. Would you like to let them in before starting?',
      confirmButtonText: count == 0 ? 'Start session' : 'Admit all and start',
      type: ConfirmationDialogType.standard,
      scrollable: true,
      onConfirm: () async {
        if (count > 0) {
          final admitted = await admission!.onAdmitAll();
          if (!admitted || !context.mounted) return;
        }
        await start();
      },
      extraButtons: [
        if (count > 0)
          ConfirmationDialogButton.outlined(
            onConfirm: start,
            child: const Text('Start without admitting'),
          ),
      ],
    );
  }
}
