import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart'
    as mobile_api
    show RoomStatus;
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/options/end_session_confirmation_dialog.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

class LeaveSessionConfirmationDialog extends ConsumerWidget {
  const LeaveSessionConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final isEnded = ref.watch(
      currentSessionStateProvider.select(
        (s) => s?.roomState.status == mobile_api.RoomStatus.ended,
      ),
    );
    return ConfirmationDialog(
      content: 'Are you sure you want to leave the session?',
      confirmButtonText: 'Leave session',
      onConfirm: () async {
        TotemRouter.instance.setTabCloseConfirmationEnabled(false);
        Navigator.of(context).pop(true);
      },
      extraButtons: [
        if (isKeeper && !isEnded)
          ConfirmationDialogButton.outlined(
            onConfirm: () async {
              final currentSession = ref.read(currentSessionProvider);
              if (currentSession == null) return;
              await endSessionWithErrorHandling(context, currentSession);
              TotemRouter.instance.setTabCloseConfirmationEnabled(false);
              if (context.mounted) Navigator.of(context).pop(true);
            },
            type: ConfirmationDialogType.destructive,
            child: const Text('End session and Leave'),
          ),
      ],
    );
  }
}
