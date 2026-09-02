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
  final _portalController = OverlayPortalController();
  final GlobalKey _buttonKey = GlobalKey();
  var _isOpen = false;

  void _openPicker() {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    _portalController.show();
  }

  void _dismiss() {
    _portalController.hide();
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (_) => EmojiBarOverlay(
        buttonKey: _buttonKey,
        onEmojiSelected: widget.onEmojiSelected,
        onDismissed: _dismiss,
      ),
      child: ActionBarButton(
        key: _buttonKey,
        semanticsLabel: 'Send reaction',
        semanticsHint: 'Open emoji selection overlay',
        active: _isOpen,
        onPressed: _openPicker,
        child: const TotemIcon(TotemIcons.reaction),
      ),
    );
  }
}
