import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/options_sheet.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar_chat_button.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar_emoji_button.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar_mic_button.dart';
import 'package:totem_app/shared/totem_icons.dart';

typedef ActionBarButtonToggleCallback =
    Future<void> Function(bool shouldEnable);

class ActionBarButton extends StatelessWidget {
  const ActionBarButton({
    required this.child,
    required this.onPressed,
    this.semanticsLabel,
    this.square = true,
    this.active = false,
    this.semanticsHint,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool active;
  final bool square;

  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = active ? AppTheme.mauve : AppTheme.white;
    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: semanticsHint,
      enabled: onPressed != null,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          decoration: BoxDecoration(
            color: active ? AppTheme.white : AppTheme.mauve,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                color: foregroundColor,
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: foregroundColor,
                ),
                child: SizedBox.square(
                  dimension: square ? 24 : null,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionBar extends StatelessWidget {
  const ActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(30),
        ),
        margin: const EdgeInsetsDirectional.only(bottom: 20),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 20,
            children: [
              for (final child in children) child,
            ],
          ),
        ),
      ),
    );
  }
}

class SessionActionBar extends ConsumerWidget {
  const SessionActionBar({super.key});

  static final GlobalKey actionBarKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final currentScreen = ref.watch(resolveCurrentScreenProvider);
    final user = session?.room?.localParticipant;

    if (session == null || currentScreen == null || user == null) {
      return const SizedBox.shrink();
    }

    final microphoneButton = ActionBarMicButton(
      participant: user,
      onToggle: (shouldEnable) async {
        if (shouldEnable) {
          await session.devices.enableMicrophone();
        } else {
          await session.devices.disableMicrophone();
        }
      },
    );

    final cameraButton = SessionActionBarCameraButton(
      session: session,
      participant: user,
    );

    final emojiBarButton = ActionBarEmojiButton(
      onEmojiSelected: (emoji) {
        session.messaging.sendReaction(emoji);
      },
    );

    const chatButton = ActionBarChatButton();

    final moreButton = ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 40,
        maxHeight: 40,
      ),
      child: IconButton(
        padding: EdgeInsetsDirectional.zero,
        onPressed: () => showOptionsSheet(
          context,
          ref.read(currentSessionStateProvider)!,
          session.event!,
        ),
        icon: const TotemIcon(
          TotemIcons.more,
          color: Colors.white,
        ),
        tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      ),
    );

    switch (currentScreen) {
      case RoomScreen.error:
      case RoomScreen.disconnected:
      case RoomScreen.loading:
        return const SizedBox.shrink();
      case RoomScreen.listening:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            emojiBarButton,
            chatButton,
            moreButton,
          ],
        );
      case RoomScreen.speaking:
      case RoomScreen.passing:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            chatButton,
            moreButton,
          ],
        );
      case RoomScreen.receiving:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            chatButton,
            moreButton,
          ],
        );
    }
  }
}
