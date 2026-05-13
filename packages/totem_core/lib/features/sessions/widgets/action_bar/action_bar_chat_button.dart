import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/popups.dart';

class ActionBarChatButton extends ConsumerStatefulWidget {
  const ActionBarChatButton({super.key});

  @override
  ConsumerState<ActionBarChatButton> createState() =>
      _ActionBarChatButtonState();
}

class _ActionBarChatButtonState extends ConsumerState<ActionBarChatButton> {
  bool _chatSheetOpen = false;
  bool _hasPendingSessionChatMessages = false;
  PopupRequest? _notificationPopup;

  @override
  void dispose() {
    _notificationPopup?.dismissActive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      lastSessionMessageProvider,
      (previous, next) {
        if (next == null || identical(previous, next)) return;
        if (!mounted || _chatSheetOpen) return;
        _notificationPopup?.dismissActive();
        _notificationPopup = showNotificationPopup(
          context,
          icon: TotemIcons.chat,
          title: 'New message',
          message: next.message,
        );
        if (next.sender) return;
        setState(() => _hasPendingSessionChatMessages = true);
      },
    );
    return ActionBarButton(
      semanticsLabel: 'Chat',
      active: _chatSheetOpen,
      onPressed: () async {
        if (!mounted) return;
        _notificationPopup?.dismissActive();
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
