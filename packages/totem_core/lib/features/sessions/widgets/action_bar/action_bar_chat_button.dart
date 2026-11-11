import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart'
    show SessionChatMessage;
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
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
    return user?.slug.value ?? user?.email;
  }

  @override
  void dispose() {
    _notificationController.dispose();
    super.dispose();
  }

  void _toggleChat({required bool fromUnread, String? thread}) {
    if (!mounted) return;
    _notification?.dismissActive();

    if (fromUnread) {
      ref.read(sessionChatThreadTargetProvider.notifier).target = thread;
    }

    final chat = ref.read(sessionChatOpenProvider.notifier);
    if (fromUnread || !chat.open) {
      chat.open = true;
    } else {
      chat.open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChatOpen = ref.watch(sessionChatOpenProvider);
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
          _toggleChat(thread: thread, fromUnread: true);
        },
      );
      ref.read(sessionChatUnreadThreadsProvider.notifier).markUnread(thread);
    });

    return ActionBarTooltip(
      message: '${isChatOpen ? 'Close' : 'Open'} chat (C)',
      child: ActionBarButton(
        semanticsLabel: 'Chat',
        role: ActionBarButtonRole.sheet(open: isChatOpen),
        onPressed: () {
          final latestUnread = ref
              .read(sessionChatUnreadThreadsProvider.notifier)
              .latestUnreadThread;
          _toggleChat(
            thread: latestUnread?.thread,
            fromUnread: latestUnread != null,
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
      ),
    );
  }
}
