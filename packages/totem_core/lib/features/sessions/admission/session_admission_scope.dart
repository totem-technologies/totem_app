import 'package:flutter/widgets.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';

/// Live admission queue state and actions for descendants of the session.
class SessionAdmissionScope extends InheritedWidget {
  const SessionAdmissionScope({
    required this.requests,
    required this.attempts,
    required this.enabled,
    required this.busy,
    required this.onDecision,
    required this.onDeclinePermanently,
    required this.onAdmitAll,
    required this.onRetry,
    required this.onResetCorruptData,
    required super.child,
    super.key,
  });

  final List<AdmissionRequest> requests;
  final List<KeeperAdmissionAttempt> attempts;
  final bool enabled;
  final bool busy;
  final VoidCallback? onRetry;
  final Future<void> Function()? onResetCorruptData;
  final Future<void> Function(AdmissionRequest, bool) onDecision;
  final Future<void> Function(AdmissionRequest) onDeclinePermanently;
  final Future<bool> Function() onAdmitAll;

  static SessionAdmissionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionAdmissionScope>();

  @override
  bool updateShouldNotify(SessionAdmissionScope oldWidget) => true;
}
