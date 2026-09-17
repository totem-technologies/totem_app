import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart'
    show SessionChatMessage;
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

  final _notificationController = NotificationController();
  NotificationRequest? _notification;

  String _notificationTitle(SessionChatMessage message) {
    final participant = message.participant;
    final keeperIdentity = ref
        .read(currentSessionStateProvider)
        ?.roomState
        .keeper;
    final isFromKeeper =
        message.isEveryoneThread ||
        (keeperIdentity != null &&
            keeperIdentity.isNotEmpty &&
            participant?.identity == keeperIdentity);
    if (isFromKeeper) return 'New message from Keeper';

    final name = participant?.name;
    return 'New message from ${name != null && name.isNotEmpty ? name : 'someone'}';
  }

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
    _notificationController.dispose();
    super.dispose();
  }

  Future<void> _openChat({required bool fromUnread, String? thread}) async {
    if (!mounted) return;
    _notification?.dismissActive();

    if (fromUnread) {
      ref.read(sessionChatThreadTargetProvider.notifier).target = thread;
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
    final hasUnreadThreads = ref.watch(
      sessionChatUnreadThreadsProvider.select((threads) => threads.isNotEmpty),
    );

    ref.listen(lastSessionMessageProvider, (previous, next) {
      if (next == null || identical(previous, next)) return;
      if (!mounted || next.sender) return;
      final thread = next.threadTargetFor(_localIdentity());
      // Only the thread on screen is already "read"; anything else still
      // needs to be announced even while the panel is open.
      if (isChatOpen && thread == visibleThread) return;
      _notification?.dismissActive();
      _notification = _notificationController.showTimed(
        context,
        icon: TotemIcons.chat,
        title: _notificationTitle(next),
        message: next.message,
        onTap: () {
          unawaited(_openChat(thread: thread, fromUnread: true));
        },
      );
      ref.read(sessionChatUnreadThreadsProvider.notifier).markUnread(thread);
    });
    return ActionBarButton(
      semanticsLabel: 'Chat',
      role: ActionBarButtonRole.sheet(open: isChatOpen),
      onPressed: () {
        final latestUnread = ref
            .read(sessionChatUnreadThreadsProvider.notifier)
            .latestUnreadThread;
        unawaited(
          _openChat(
            thread: latestUnread?.thread,
            fromUnread: latestUnread != null,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const TotemIcon(TotemIcons.chat),
          if (hasUnreadThreads)
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
