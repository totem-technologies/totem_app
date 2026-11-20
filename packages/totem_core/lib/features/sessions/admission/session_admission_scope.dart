import 'package:flutter/widgets.dart';
import 'package:totem_core/core/api/api_client/api_client.dart'
    show Participant;

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
    required this.onRefresh,
    required this.onRetryUnresolved,
    required this.error,
    required super.child,
    super.key,
  });

  final List<Participant> requests;
  final List<Participant> attempts;
  final bool enabled;
  final bool busy;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;
  final Future<void> Function()? onRetryUnresolved;
  final String? error;
  final Future<void> Function(Participant, bool) onDecision;
  final Future<void> Function(Participant) onDeclinePermanently;
  final Future<bool> Function() onAdmitAll;

  static SessionAdmissionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionAdmissionScope>();

  @override
  bool updateShouldNotify(SessionAdmissionScope oldWidget) => true;
}
