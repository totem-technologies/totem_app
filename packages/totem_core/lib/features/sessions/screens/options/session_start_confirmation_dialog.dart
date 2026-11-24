import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/features/sessions/presentation/session_action_feedback.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

/// Confirms starting with the live admission queue before changing room state.
class SessionStartConfirmationDialog extends ConsumerStatefulWidget {
  const SessionStartConfirmationDialog({required this.onStart, super.key});

  final Future<bool> Function() onStart;

  @override
  ConsumerState<SessionStartConfirmationDialog> createState() =>
      _SessionStartConfirmationDialogState();
}

class _SessionStartConfirmationDialogState
    extends ConsumerState<SessionStartConfirmationDialog> {
  int? _actionCount;

  Future<void> _start(int count, {Future<bool> Function()? admitAll}) async {
    setState(() => _actionCount = count);
    var started = false;
    try {
      if (admitAll != null && (!await admitAll() || !mounted)) return;
      final feedback = ref.read(sessionActionFeedbackProvider.notifier);
      try {
        started = await widget.onStart();
      } catch (error, stackTrace) {
        // The dialog stays open, so confirming again is the retry.
        feedback.report(
          SessionAction.startSession,
          error,
          stackTrace: stackTrace,
        );
        return;
      }
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
