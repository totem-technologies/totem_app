import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/presentation/session_action_feedback.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

/// Presents session action failures as room banners, like the room screen.
///
/// Place it below the app's root [Overlay] and above any session dialogs.
class ActionFeedbackHost extends StatefulWidget {
  const ActionFeedbackHost({required this.child, super.key});
  final Widget child;

  @override
  State<ActionFeedbackHost> createState() => _ActionFeedbackHostState();
}

class _ActionFeedbackHostState extends State<ActionFeedbackHost> {
  final _notifications = NotificationController();

  @override
  void dispose() {
    _notifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SessionActionFeedbackEffects(
    notifications: _notifications,
    child: widget.child,
  );
}
