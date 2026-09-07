import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/config/theme.dart';
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
  bool _hasPendingSessionChatMessages = false;
  NotificationRequest? _notification;

  @override
  void dispose() {
    _notification?.dismissActive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dockedOpen = ref.watch(sessionChatOpenProvider);
    final isChatOpen = _chatSheetOpen || dockedOpen;

    ref.listen(
      lastSessionMessageProvider,
      (previous, next) {
        if (next == null || identical(previous, next)) return;
        if (!mounted || isChatOpen || next.sender) return;
        _notification?.dismissActive();
        _notification = NotificationController().showTimed(
          context,
          icon: TotemIcons.chat,
          title: 'New message',
          message: next.message,
        );
        setState(() => _hasPendingSessionChatMessages = true);
      },
    );
    return ActionBarButton(
      semanticsLabel: 'Chat',
      role: ActionBarButtonRole.sheet(open: isChatOpen),
      onPressed: () async {
        if (!mounted) return;
        _notification?.dismissActive();
        setState(() => _hasPendingSessionChatMessages = false);

        // Wide desktop docks the panel beside the video; everything else
        // still opens the existing sheet / dialog.
        if (shouldDockSessionChat(context)) {
          ref.read(sessionChatOpenProvider.notifier).toggle();
          return;
        }

        ref.read(sessionChatOpenProvider.notifier).setOpen(false);
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
          if (_hasPendingSessionChatMessages && !dockedOpen)
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
