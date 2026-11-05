import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/widgets/session_admission_list.dart';

import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

enum _DeclineAction { once, permanently }

/// The Widgetbook admission list hosted above the existing live Session UI.
class KeeperAdmissionPanel extends StatefulWidget {
  const KeeperAdmissionPanel({
    required this.requests,
    required this.onDecision,
    required this.onAdmitAll,
    required this.onClose,
    required this.busy,
    required this.desktop,
    this.attempts = const [],
    this.onDeclinePermanently,
    this.embedded = false,
    super.key,
  });

  final List<AdmissionRequest> requests;
  final List<KeeperAdmissionAttempt> attempts;
  final Future<void> Function(AdmissionRequest request, bool approve)
  onDecision;
  final Future<void> Function(AdmissionRequest request)? onDeclinePermanently;
  final VoidCallback onAdmitAll;
  final VoidCallback onClose;
  final bool busy;
  final bool desktop;

  /// Whether the panel is hosted by a parent-owned docked surface.
  final bool embedded;

  @override
  State<KeeperAdmissionPanel> createState() => _KeeperAdmissionPanelState();
}

class _KeeperAdmissionPanelState extends State<KeeperAdmissionPanel> {
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

  bool _isCurrent(AdmissionRequest request) => widget.requests.any(
    (current) =>
        current.id == request.id &&
        current.senderIdentity == request.senderIdentity,
  );

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final theme = Theme.of(context);
    final statuses = widget.attempts.where(
      (attempt) => attempt.status != KeeperAdmissionStatus.requested,
    );
    final content = SizedBox(
      width: widget.desktop ? 380 : double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            SessionAdmissionList(
              guests: [
                for (final request in widget.requests)
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
              busy: widget.busy,
              onClose: widget.onClose,
              onAdmit: (id) {
                final request = widget.requests.firstWhere(
                  (request) => request.id == id,
                );
                unawaited(widget.onDecision(request, true));
              },
              onDecline: (id) async {
                final request = widget.requests.firstWhere(
                  (request) => request.id == id,
                );
                final action = await showDialog<_DeclineAction>(
                  context: context,
                  useRootNavigator: false,
                  builder: (dialogContext) => ConfirmationDialog(
                    content:
                        'Are you sure you want to decline ${request.displayName}?'
                        '${widget.onDeclinePermanently == null ? '' : "\n\nDecline Permanently also declines future requests for this Session. You can undo this in Declined Participants."}',
                    scrollable: true,
                    confirmButtonText: 'Decline',
                    onConfirm: () async => Navigator.of(
                      dialogContext,
                    ).pop(_DeclineAction.once),
                    extraButtons: [
                      if (widget.onDeclinePermanently != null)
                        ConfirmationDialogButton.outlined(
                          type: ConfirmationDialogType.destructive,
                          onConfirm: () async => Navigator.of(
                            dialogContext,
                          ).pop(_DeclineAction.permanently),
                          child: const Text('Decline Permanently'),
                        ),
                    ],
                  ),
                );
                if (!mounted || !_isCurrent(request)) return;
                if (action == _DeclineAction.once) {
                  await widget.onDecision(request, false);
                } else if (action == _DeclineAction.permanently) {
                  await widget.onDeclinePermanently?.call(request);
                }
              },
              onAdmitAll: widget.onAdmitAll,
            ),
            for (final attempt in statuses)
              Semantics(
                label:
                    '${attempt.request.displayName}: ${_status(attempt.status)}',
                child: Text(
                  '${attempt.request.displayName} · ${_status(attempt.status)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.embedded) return SizedBox.expand(child: content);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: height * (widget.desktop ? 0.65 : 0.35),
        ),
        child: content,
      ),
    );
  }
}
