import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';

class SessionKeyboardShortcuts extends ConsumerStatefulWidget {
  const SessionKeyboardShortcuts({
    required this.child,
    this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

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
    if (_hasModifierPressed() ||
        _hasEditableFocus() ||
        _hasBlockingNavigatorRoute()) {
      return false;
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

    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyZ:
        unawaited(_toggleMicrophone(session));
        return true;
      case LogicalKeyboardKey.keyX:
        unawaited(_toggleCamera(session));
        return true;
      default:
        return false;
    }
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
      if (session.devices.isCameraEnabled) {
        await session.devices.disableCamera();
      } else {
        await session.devices.enableCamera();
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
      if (session.devices.isMicrophoneEnabled) {
        await session.devices.disableMicrophone();
      } else {
        await session.devices.enableMicrophone();
      }
    } finally {
      _isTogglingMicrophone = false;
    }
  }

  String? _reactionForKey(LogicalKeyboardKey logicalKey) {
    return switch (logicalKey) {
      LogicalKeyboardKey.keyA => EmojiBar.defaultEmojis[0],
      LogicalKeyboardKey.keyS => EmojiBar.defaultEmojis[1],
      LogicalKeyboardKey.keyD => EmojiBar.defaultEmojis[2],
      LogicalKeyboardKey.keyF => EmojiBar.defaultEmojis[3],
      _ => null,
    };
  }
}
