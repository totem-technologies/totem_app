import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';

class ActionBarEmojiButton extends ConsumerStatefulWidget {
  const ActionBarEmojiButton({required this.onEmojiSelected, super.key});

  final ValueChanged<String> onEmojiSelected;

  @override
  ConsumerState<ActionBarEmojiButton> createState() =>
      _ActionBarEmojiButtonState();
}

class _ActionBarEmojiButtonState extends ConsumerState<ActionBarEmojiButton> {
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
    ref.listen(sessionChatOpenProvider, (previous, next) {
      if (next && _isOpen) _dismiss();
    });

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
        role: ActionBarButtonRole.sheet(open: _isOpen),
        onPressed: _openPicker,
        child: const TotemIcon(TotemIcons.reaction),
      ),
    );
  }
}
