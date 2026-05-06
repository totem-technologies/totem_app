import 'package:flutter/material.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';

class ActionBarEmojiButton extends StatefulWidget {
  const ActionBarEmojiButton({required this.onEmojiSelected, super.key});

  final ValueChanged<String> onEmojiSelected;

  @override
  State<ActionBarEmojiButton> createState() => _ActionBarEmojiButtonState();
}

class _ActionBarEmojiButtonState extends State<ActionBarEmojiButton> {
  var _isOpen = false;

  Future<void> _openPicker(BuildContext buttonContext) async {
    if (_isOpen) return;

    setState(() => _isOpen = true);
    try {
      await showEmojiBar(
        buttonContext,
        onEmojiSelected: widget.onEmojiSelected,
      );
    } finally {
      if (mounted) setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return ActionBarButton(
          semanticsLabel: 'Send reaction',
          semanticsHint: 'Open emoji selection overlay',
          active: _isOpen,
          onPressed: () => _openPicker(buttonContext),
          child: const TotemIcon(TotemIcons.reaction),
        );
      },
    );
  }
}
