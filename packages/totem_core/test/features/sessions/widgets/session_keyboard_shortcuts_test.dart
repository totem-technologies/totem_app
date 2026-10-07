import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';

void main() {
  testWidgets('prejoin ignores C and keeps Z and X shortcuts active', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final container = ProviderContainer();
    addTearDown(container.dispose);
    var microphoneToggles = 0;
    var cameraToggles = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: SessionKeyboardShortcuts(
          enableChatShortcut: false,
          onToggleMicrophone: () async => microphoneToggles++,
          onToggleCamera: () async => cameraToggles++,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.sendKeyEvent(ActionBarShortcut.chatKey);
    await tester.pump();
    await tester.sendKeyEvent(ActionBarShortcut.microphoneKey);
    await tester.pump();
    await tester.sendKeyEvent(ActionBarShortcut.cameraKey);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;

    check(container.read(sessionChatOpenProvider)).isFalse();
    check(microphoneToggles).equals(1);
    check(cameraToggles).equals(1);
  });
}
