import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
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

  /// Threads with unread messages. Null is the Everyone thread, so this is
  /// per-thread rather than a single flag: a keeper reading Everyone still
  /// needs to see that a private support request arrived.
  final Set<String?> _unreadThreads = {};
  String? _latestUnreadThread;
  NotificationRequest? _notification;

  String? _localIdentity() {
    final user = ref.read(authControllerProvider).user;
    final roomIdentity = ref
        .read(currentSessionProvider)
        ?.room
        ?.localParticipant
        ?.identity;
    if (roomIdentity != null && roomIdentity.isNotEmpty) return roomIdentity;
    return user?.slug ?? user?.email;
  }

  @override
  void dispose() {
    _notification?.dismissActive();
    super.dispose();
  }

  Future<void> _openChat({required bool fromUnread, String? thread}) async {
    if (!mounted) return;
    _notification?.dismissActive();

    if (fromUnread) {
      ref.read(sessionChatThreadTargetProvider.notifier).target = thread;
      setState(() => _unreadThreads.remove(thread));
    } else {
      setState(
        () => _unreadThreads.remove(ref.read(sessionChatThreadTargetProvider)),
      );
    }

    // Wide desktop docks the panel beside the video; everything else
    // still opens the existing sheet / dialog.
    if (shouldDockSessionChat(context)) {
      if (fromUnread) {
        ref.read(sessionChatOpenProvider.notifier).open = true;
        return;
      }
      ref.read(sessionChatOpenProvider.notifier).toggle();
      return;
    }

    if (_chatSheetOpen) return;

    ref.read(sessionChatOpenProvider.notifier).open = false;
    setState(() => _chatSheetOpen = true);
    try {
      await showSessionChat(context);
    } finally {
      if (mounted) setState(() => _chatSheetOpen = false);
    }
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
      final thread = next.threadTargetFor(_localIdentity());
      // Only the thread on screen is already "read"; anything else still
      // needs to be announced even while the panel is open.
      if (isChatOpen && thread == visibleThread) return;
      _notification?.dismissActive();
      _latestUnreadThread = thread;
      _notification = NotificationController().showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'New message',
        message: next.message,
        onTap: () {
          unawaited(_openChat(thread: thread, fromUnread: true));
        },
      );
      setState(() => _unreadThreads.add(thread));
    });
    return ActionBarButton(
      semanticsLabel: 'Chat',
      role: ActionBarButtonRole.sheet(open: isChatOpen),
      onPressed: () {
        final hasUnread = _unreadThreads.isNotEmpty;
        unawaited(
          _openChat(thread: _latestUnreadThread, fromUnread: hasUnread),
        );
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
