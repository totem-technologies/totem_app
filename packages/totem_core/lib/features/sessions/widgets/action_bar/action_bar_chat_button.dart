import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class ActionBarChatButton extends ConsumerStatefulWidget {
  const ActionBarChatButton({super.key});

  @override
  ConsumerState<ActionBarChatButton> createState() =>
      _ActionBarChatButtonState();
}

class _ActionBarChatButtonState extends ConsumerState<ActionBarChatButton> {
  bool _chatSheetOpen = false;

  /// Threads with unread messages. Null is the Everyone thread, so this is
  /// per-thread rather than a single flag: a keeper reading Everyone still
  /// needs to see that a private support request arrived.
  final Set<String?> _unreadThreads = {};
  NotificationRequest? _notification;

  /// The thread a message belongs to from this client's point of view.
  static String? _threadOf(SessionChatMessage message) {
    if (message.isEveryoneThread) return null;
    return message.sender
        ? message.recipientIdentity
        : message.participant?.identity;
  }

  @override
  void dispose() {
    _notification?.dismissActive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The docked sidebar only actually renders on a wide viewport, so a stale
    // flag from before a resize must not make the button read as open.
    final dockedOpen =
        ref.watch(sessionChatOpenProvider) && shouldDockSessionChat(context);
    final isChatOpen = _chatSheetOpen || dockedOpen;
    final visibleThread = ref.watch(sessionChatThreadTargetProvider);

    ref.listen(lastSessionMessageProvider, (previous, next) {
      if (next == null || identical(previous, next)) return;
      if (!mounted || next.sender) return;
      // Only the thread on screen is already "read"; anything else still
      // needs to be announced even while the panel is open.
      final thread = _threadOf(next);
      if (isChatOpen && thread == visibleThread) return;
      _notification?.dismissActive();
      _notification = NotificationController().showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'New message',
        message: next.message,
      );
      setState(() => _unreadThreads.add(thread));
    });
    return ActionBarButton(
      semanticsLabel: 'Chat',
      role: ActionBarButtonRole.sheet(open: isChatOpen),
      onPressed: () async {
        if (!mounted) return;
        _notification?.dismissActive();
        setState(() => _unreadThreads.remove(visibleThread));

        // Wide desktop docks the panel beside the video; everything else
        // still opens the existing sheet / dialog.
        if (shouldDockSessionChat(context)) {
          ref.read(sessionChatOpenProvider.notifier).toggle();
          return;
        }

        ref.read(sessionChatOpenProvider.notifier).open = false;
        setState(() => _chatSheetOpen = true);
        try {
          await showSessionChat(context);
        } finally {
          if (mounted) setState(() => _chatSheetOpen = false);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const TotemIcon(TotemIcons.chat),
          if (_unreadThreads.isNotEmpty && !dockedOpen)
            Container(
              height: 4,
              width: 4,
              decoration: const BoxDecoration(
                color: AppTheme.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
