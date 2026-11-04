import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/widgets/session_admission_list.dart';

import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

/// The Widgetbook admission list hosted above the existing live Session UI.
class KeeperAdmissionPanel extends StatelessWidget {
  const KeeperAdmissionPanel({
    required this.requests,
    required this.onDecision,
    required this.onAdmitAll,
    required this.onClose,
    required this.busy,
    required this.desktop,
    this.attempts = const [],
    super.key,
  });

  final List<AdmissionRequest> requests;
  final List<KeeperAdmissionAttempt> attempts;
  final Future<void> Function(AdmissionRequest request, bool approve)
  onDecision;
  final VoidCallback onAdmitAll;
  final VoidCallback onClose;
  final bool busy;
  final bool desktop;

  String _status(KeeperAdmissionStatus status) => switch (status) {
    KeeperAdmissionStatus.requested => 'Waiting for a decision',
    KeeperAdmissionStatus.joining => 'Approval sent · joining',
    KeeperAdmissionStatus.joined => 'Joined the Session',
    KeeperAdmissionStatus.joinFailed => 'Could not join · may request again',
    KeeperAdmissionStatus.timedOut => 'Join confirmation timed out',
    KeeperAdmissionStatus.denied => 'Declined',
    KeeperAdmissionStatus.cancelled => 'Canceled',
    KeeperAdmissionStatus.expired => 'Request expired',
  };

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final theme = Theme.of(context);
    final statuses = attempts.where(
      (attempt) => attempt.status != KeeperAdmissionStatus.requested,
    );
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: height * (desktop ? 0.65 : 0.35),
        ),
        child: SizedBox(
          width: desktop ? 380 : double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                SessionAdmissionList(
                  guests: [
                    for (final request in requests)
                      SessionAdmissionGuest(
                        id: request.id,
                        name: request.displayName,
                        avatar: UserAvatar.slug(
                          request.senderIdentity,
                          radius: 18,
                          borderWidth: 0,
                        ),
                      ),
                  ],
                  busy: busy,
                  onClose: onClose,
                  onAdmit: (id) {
                    final request = requests.firstWhere(
                      (request) => request.id == id,
                    );
                    unawaited(onDecision(request, true));
                  },
                  onDecline: (id) async {
                    final request = requests.firstWhere(
                      (request) => request.id == id,
                    );
                    final confirmed = await showDialog<bool>(
                      context: context,
                      useRootNavigator: false,
                      builder: (dialogContext) => ConfirmationDialog(
                        content:
                            'Are you sure you want to decline ${request.displayName}?',
                        confirmButtonText: 'Decline',
                        onConfirm: () async =>
                            Navigator.of(dialogContext).pop(true),
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await onDecision(request, false);
                    }
                  },
                  onAdmitAll: onAdmitAll,
                ),
                for (final attempt in statuses)
                  Semantics(
                    label:
                        '${attempt.request.displayName}: ${_status(attempt.status)}',
                    child: Text(
                      '${attempt.request.displayName} · ${_status(attempt.status)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
