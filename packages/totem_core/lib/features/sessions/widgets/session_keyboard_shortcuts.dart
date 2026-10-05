import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';

class SessionKeyboardShortcuts extends ConsumerStatefulWidget {
  const SessionKeyboardShortcuts({
    required this.child,
    this.navigatorKey,
    this.enableEmojiReactions = true,
    this.onToggleMicrophone,
    this.onToggleCamera,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool enableEmojiReactions;
  final Future<void> Function()? onToggleMicrophone;
  final Future<void> Function()? onToggleCamera;

  @override
  ConsumerState<SessionKeyboardShortcuts> createState() =>
      _SessionKeyboardShortcutsState();
}

class _SessionKeyboardShortcutsState
    extends ConsumerState<SessionKeyboardShortcuts> {
  bool get _supportsKeyboardShortcuts =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia => false,
      };

  @override
  void initState() {
    super.initState();
    if (_supportsKeyboardShortcuts) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  @override
  void dispose() {
    if (_supportsKeyboardShortcuts) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    if (_hasModifierPressed() || _hasEditableFocus()) return false;

    if (event.logicalKey == ActionBarShortcut.chatKey) {
      final chat = ref.read(sessionChatOpenProvider.notifier);
      if (chat.open) {
        chat.open = false;
        return true;
      }
      if (_hasBlockingNavigatorRoute()) return false;
      ref.read(sessionPromptsOpenProvider.notifier).open = false;
      chat.open = true;
      return true;
    }

    if (_hasBlockingNavigatorRoute() || ref.read(sessionChatOpenProvider)) {
      return false;
    }

    if (event.logicalKey == ActionBarShortcut.microphoneKey &&
        widget.onToggleMicrophone != null) {
      unawaited(widget.onToggleMicrophone!());
      return true;
    }
    if (event.logicalKey == ActionBarShortcut.cameraKey &&
        widget.onToggleCamera != null) {
      unawaited(widget.onToggleCamera!());
      return true;
    }

    final session = ref.read(currentSessionProvider);
    final currentScreen = ref.read(resolveCurrentScreenProvider);
    if (session == null ||
        currentScreen == null ||
        !_supportsShortcutsForScreen(currentScreen)) {
      return false;
    }

    final reaction = _reactionForKey(event.logicalKey);
    if (reaction != null) {
      unawaited(session.messaging.sendReaction(reaction));
      return true;
    }

    if (event.logicalKey == ActionBarShortcut.microphoneKey) {
      unawaited(_toggleMicrophone(session));
      return true;
    }
    if (event.logicalKey == ActionBarShortcut.cameraKey) {
      unawaited(_toggleCamera(session));
      return true;
    }
    return false;
  }

  bool _supportsShortcutsForScreen(RoomScreen screen) {
    return switch (screen) {
      RoomScreen.listening ||
      RoomScreen.speaking ||
      RoomScreen.passing ||
      RoomScreen.receiving => true,
      RoomScreen.loading ||
      RoomScreen.error ||
      RoomScreen.disconnected => false,
    };
  }

  bool _hasModifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed;
  }

  bool _hasEditableFocus() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) {
      return false;
    }

    return focusedContext.widget is EditableText ||
        focusedContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _hasBlockingNavigatorRoute() {
    return widget.navigatorKey?.currentState?.canPop() ?? false;
  }

  bool _isTogglingCamera = false;

  Future<void> _toggleCamera(SessionController session) async {
    if (_isTogglingCamera) return;
    _isTogglingCamera = true;
    try {
      await session.devices.toggleCamera();
    } finally {
      _isTogglingCamera = false;
    }
  }

  bool _isTogglingMicrophone = false;

  Future<void> _toggleMicrophone(SessionController session) async {
    if (_isTogglingMicrophone) return;
    _isTogglingMicrophone = true;
    try {
      if (session.devices.isMicrophoneEnabled) {
        await session.devices.disableMicrophone();
      } else {
        await session.devices.enableMicrophone();
      }
    } finally {
      _isTogglingMicrophone = false;
    }
  }

  Emoji? _reactionForKey(LogicalKeyboardKey logicalKey) {
    if (!widget.enableEmojiReactions) return null;
    final reactionIndex = ActionBarShortcut.reactionKeys.indexOf(logicalKey);
    return reactionIndex < 0 ? null : EmojiBar.defaultEmojis[reactionIndex];
  }
}
