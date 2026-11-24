import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/presentation/session_action_feedback.dart';
import 'package:totem_core/features/sessions/presentation/session_device_effects.dart';
import 'package:totem_core/features/sessions/presentation/session_environment_effects.dart';
import 'package:totem_core/features/sessions/presentation/session_status_effects.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

/// One notification queue preserves precedence across independent effect owners.
class SessionPresentationEffects extends ConsumerStatefulWidget {
  const SessionPresentationEffects({
    required this.now,
    required this.child,
    super.key,
  });
  final ValueGetter<DateTime> now;
  final Widget child;
  @override
  ConsumerState<SessionPresentationEffects> createState() =>
      _SessionPresentationEffectsState();
}

class _SessionPresentationEffectsState
    extends ConsumerState<SessionPresentationEffects> {
  final _notifications = NotificationController();
  @override
  void dispose() {
    _notifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    ref.listen(currentSessionProvider, (previous, next) {
      if (!identical(previous, next)) {
        _notifications.dismissAll(immediate: true);
      }
    });
    final cues = ref.read(sessionCuesServiceProvider);
    ref.listen(resolveCurrentScreenProvider, (previous, next) {
      if (previous != RoomScreen.receiving && next == RoomScreen.receiving) {
        cues.playTotemReceivedCue();
      }
    });
    ref.listen(roomStatusProvider, (previous, next) {
      if ((previous == RoomStatus.waitingRoom && next == RoomStatus.active) ||
          (previous == RoomStatus.active && next == RoomStatus.ended)) {
        cues.playSessionTransitionCue();
      }
    });
    ref.listen(emojiReactionsProvider, (_, next) {
      if (!mounted) return;
      final listening =
          ref.read(resolveCurrentScreenProvider) == RoomScreen.listening;
      for (final reaction in next.where((reaction) => !reaction.displayed)) {
        unawaited(
          ref
              .read(emojiReactionsProvider.notifier)
              .displayReaction(context, reaction, listening),
        );
      }
    });
    return SessionStatusEffects(
      key: ObjectKey(session),
      notifications: _notifications,
      now: widget.now,
      child: SessionDeviceEffects(
        notifications: _notifications,
        child: SessionEnvironmentEffects(
          notifications: _notifications,
          child: SessionActionFeedbackEffects(
            notifications: _notifications,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
