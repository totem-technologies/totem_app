import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/chat.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class ActionBarChatButton extends ConsumerStatefulWidget {
  const ActionBarChatButton({super.key});

  @override
  ConsumerState<ActionBarChatButton> createState() =>
      _ActionBarChatButtonState();
}

class _ActionBarChatButtonState extends ConsumerState<ActionBarChatButton> {
  bool _chatSheetOpen = false;
  bool _hasPendingSessionChatMessages = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(
      lastSessionMessageProvider,
      (previous, next) {
        if (next == null || identical(previous, next)) return;
        if (!mounted || _chatSheetOpen) return;
        setState(() => _hasPendingSessionChatMessages = true);
        showNotificationPopup(
          context,
          icon: TotemIcons.chat,
          title: 'New message',
          message: next.message,
          // controller: _notificationController,
        );
      },
    );
    return ActionBarButton(
      semanticsLabel: 'Chat',
      active: _chatSheetOpen,
      onPressed: () async {
        if (!mounted) return;
        setState(() {
          _hasPendingSessionChatMessages = false;
          _chatSheetOpen = true;
        });
        await showSessionChat(context);
        if (!mounted) return;
        setState(() => _chatSheetOpen = false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const TotemIcon(TotemIcons.chat),
          if (_hasPendingSessionChatMessages)
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
