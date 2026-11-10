import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

/// Confirms starting with the live admission queue before changing room state.
class SessionStartConfirmationDialog extends StatefulWidget {
  const SessionStartConfirmationDialog({required this.onStart, super.key});

  final Future<bool> Function() onStart;

  @override
  State<SessionStartConfirmationDialog> createState() =>
      _SessionStartConfirmationDialogState();
}

class _SessionStartConfirmationDialogState
    extends State<SessionStartConfirmationDialog> {
  int? _actionCount;

  Future<void> _start(int count, {Future<bool> Function()? admitAll}) async {
    setState(() => _actionCount = count);
    var started = false;
    try {
      if (admitAll != null && (!await admitAll() || !mounted)) return;
      started = await widget.onStart();
      if (started && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted && !started) setState(() => _actionCount = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admission = SessionAdmissionScope.maybeOf(context);
    final count = _actionCount ?? admission?.requests.length ?? 0;

    return ConfirmationDialog(
      title: 'Start session',
      content: count == 0
          ? 'Are you sure you want to start the session?'
          : 'You have $count ${count == 1 ? 'participant' : 'participants'} waiting. Would you like to let them in before starting?',
      confirmButtonText: count == 0 ? 'Start session' : 'Admit all and start',
      type: ConfirmationDialogType.standard,
      scrollable: true,
      // A timed-out Future would keep admitting and could still start later.
      actionTimeout: null,
      onConfirm: () =>
          _start(count, admitAll: count > 0 ? admission!.onAdmitAll : null),
      extraButtons: [
        if (count > 0)
          ConfirmationDialogButton.outlined(
            onConfirm: () => _start(count),
            child: const Text('Start without admitting'),
          ),
      ],
    );
  }
}
