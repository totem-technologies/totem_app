import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/ui/recovery.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';

class SessionKeyboardShortcuts extends ConsumerStatefulWidget {
  const SessionKeyboardShortcuts({
    required this.child,
    this.navigatorKey,
    this.enableEmojiReactions = true,
    this.enableChatShortcut = true,
    this.onToggleMicrophone,
    this.onToggleCamera,
    this.onEscape,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool enableEmojiReactions;
  final bool enableChatShortcut;
  final AsyncCallback? onToggleMicrophone;
  final AsyncCallback? onToggleCamera;

  /// Handles Escape when nothing in the room has focus; returns whether it
  /// did. A focused widget, popup or dialog gets Escape through the focus
  /// tree instead, so it closes first.
  final bool Function()? onEscape;

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

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_hasBlockingNavigatorRoute() || !_hasIdleRoomFocus()) return false;
      return widget.onEscape?.call() ?? false;
    }

    if (widget.enableChatShortcut &&
        event.logicalKey == ActionBarShortcut.chatKey) {
      final chat = ref.read(sessionPresentationProvider.notifier);
      if (ref.read(sessionChatSelectedProvider)) {
        chat.closePanel(expectedPanel: SessionPanel.chat);
        return true;
      }
      if (_hasBlockingNavigatorRoute()) return false;
      ref
          .read(sessionPresentationProvider.notifier)
          .closePanel(expectedPanel: SessionPanel.prompts);
      chat.openPanel(SessionPanel.chat);
      return true;
    }

    if (_hasBlockingNavigatorRoute() ||
        (widget.enableChatShortcut && ref.read(sessionChatSelectedProvider))) {
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

  /// Whether focus rests on a scope in the room's own focus chain rather than
  /// on a widget, or on a dialog opened outside the room navigator.
  bool _hasIdleRoomFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return true;
    if (focus is! FocusScopeNode) return false;
    final roomFocus = widget.navigatorKey?.currentState?.focusNode;
    if (roomFocus == null) return false;
    return focus == roomFocus ||
        focus.ancestors.contains(roomFocus) ||
        roomFocus.ancestors.contains(focus);
  }

  bool _hasBlockingNavigatorRoute() {
    return widget.navigatorKey?.currentState?.canPop() ?? false;
  }

  bool _isTogglingCamera = false;

  Future<void> _toggleCamera(SessionController session) async {
    if (_isTogglingCamera) return;
    _isTogglingCamera = true;
    try {
      final devices = session.devices;
      if (devices.isCameraEnabled) {
        await devices.disableCamera();
      } else {
        await turnOnMedia(context, ref, devices.control(MediaKind.camera));
      }
    } finally {
      _isTogglingCamera = false;
    }
  }

  bool _isTogglingMicrophone = false;

  Future<void> _toggleMicrophone(SessionController session) async {
    if (_isTogglingMicrophone) return;
    _isTogglingMicrophone = true;
    try {
      final devices = session.devices;
      if (devices.isMicrophoneEnabled) {
        await devices.disableMicrophone();
      } else {
        await turnOnMedia(context, ref, devices.control(MediaKind.microphone));
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
