import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart'
    show Participant, ParticipantStatus;
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/admission/session_admission_list.dart';
import 'package:totem_core/features/sessions/widgets/session_navigator_scope.dart';
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
    this.error,
    this.onRefresh,
    this.onRetryUnresolved,
    this.embedded = false,
    super.key,
  });

  final List<Participant> requests;
  final List<Participant> attempts;
  final Future<void> Function(Participant request, bool approve) onDecision;
  final Future<void> Function(Participant request)? onDeclinePermanently;
  final VoidCallback onAdmitAll;
  final VoidCallback onClose;
  final String? error;
  final VoidCallback? onRefresh;
  final AsyncCallback? onRetryUnresolved;
  final bool busy;
  final bool desktop;

  /// Whether the panel is hosted by a parent-owned docked surface.
  final bool embedded;

  @override
  State<KeeperAdmissionPanel> createState() => _KeeperAdmissionPanelState();
}

class _KeeperAdmissionPanelState extends State<KeeperAdmissionPanel> {
  String _status(ParticipantStatus status) => switch (status) {
    ParticipantStatus.pending => 'Waiting for a decision',
    ParticipantStatus.approved => 'Approval sent · joining',
    ParticipantStatus.activated => 'Joined the Session',
    ParticipantStatus.declined => 'Declined',
    ParticipantStatus.cancelled => 'Canceled',
    ParticipantStatus.expired => 'Request expired',
    ParticipantStatus.failed => 'Could not join · may request again',
    _ => status.value,
  };

  bool _isCurrent(Participant request) => widget.requests.any(
    (current) =>
        current.identity == request.identity &&
        current.requestId.value == request.requestId.value &&
        current.attemptId.value == request.attemptId.value,
  );

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final theme = Theme.of(context);
    final statuses = widget.attempts.where(
      (attempt) => !widget.requests.any(
        (request) => request.identity == attempt.identity,
      ),
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
            if (widget.error case final error?)
              Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (widget.onRefresh case final refresh?)
              OutlinedButton(
                onPressed: refresh,
                child: const Text('Retry refresh'),
              ),
            if (widget.onRetryUnresolved case final retry?)
              OutlinedButton(
                onPressed: widget.busy ? null : () => unawaited(retry()),
                child: const Text('Retry unresolved command'),
              ),
            SessionAdmissionList(
              guests: [
                for (final request in widget.requests)
                  SessionAdmissionGuest(
                    id: request.identity,
                    name: request.user.name.value ?? request.identity,
                    avatar: UserAvatar.slug(
                      request.identity,
                      radius: 18,
                      borderWidth: 0,
                    ),
                  ),
              ],
              busy: widget.busy,
              onClose: widget.onClose,
              onAdmit: (id) {
                final request = widget.requests.firstWhereOrNull(
                  (request) => request.identity == id,
                );
                if (request == null) return;
                unawaited(widget.onDecision(request, true));
              },
              onDecline: (id) async {
                final request = widget.requests.firstWhereOrNull(
                  (request) => request.identity == id,
                );
                if (request == null) return;
                final action = await showDialog<_DeclineAction>(
                  context: sessionNavigatorContext(context),
                  useRootNavigator: false,
                  builder: (dialogContext) => ConfirmationDialog(
                    content:
                        'Are you sure you want to decline ${request.user.name.value ?? request.identity}?'
                        '${widget.onDeclinePermanently == null ? '' : "\n\nDecline Permanently also declines future requests for this Session. You can undo this in Declined Participants."}',
                    scrollable: true,
                    confirmButtonText: 'Decline',
                    onConfirm: () async =>
                        Navigator.of(dialogContext).pop(_DeclineAction.once),
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
                    '${attempt.user.name.value ?? attempt.identity}: ${_status(attempt.status)}',
                child: Text(
                  '${attempt.user.name.value ?? attempt.identity} · ${_status(attempt.status)}',
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
