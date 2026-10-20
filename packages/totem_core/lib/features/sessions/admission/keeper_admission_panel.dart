import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/widgets/session_admission_list.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

/// The Widgetbook admission list hosted above the existing live Session UI.
class KeeperAdmissionPanel extends StatefulWidget {
  const new({
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

  @override
  State<KeeperAdmissionPanel> createState() => _KeeperAdmissionPanelState();
}

class _KeeperAdmissionPanelState extends State<KeeperAdmissionPanel> {
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _syncCountdown();
  }

  @override
  void didUpdateWidget(KeeperAdmissionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCountdown();
  }

  void _syncCountdown() {
    if (widget.requests.isNotEmpty && _countdown == null) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (widget.requests.isEmpty) {
      _countdown?.cancel();
      _countdown = null;
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  String _remaining(DateTime expiresAt) {
    final duration = expiresAt.difference(DateTime.now());
    if (duration <= Duration.zero) return '0:00';
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

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
    final statuses = widget.attempts.where(
      (attempt) => attempt.status != KeeperAdmissionStatus.requested,
    );
    return Material(
      color: entryCream,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.desktop ? 380 : double.infinity,
        height: widget.desktop ? height * 0.65 : height * 0.42,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              SessionAdmissionList(
                guests: [
                  for (final request in widget.requests)
                    SessionAdmissionGuest(
                      id: request.id,
                      name: request.displayName,
                      expiresLabel: _remaining(request.expiresAt),
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
                onDecline: (id) {
                  final request = widget.requests.firstWhere(
                    (request) => request.id == id,
                  );
                  unawaited(widget.onDecision(request, false));
                },
                onAdmitAll: widget.onAdmitAll,
              ),
              for (final attempt in statuses)
                Semantics(
                  label:
                      '${attempt.request.displayName}: ${_status(attempt.status)}',
                  child: Text(
                    '${attempt.request.displayName} · ${_status(attempt.status)}',
                    style: entryMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
