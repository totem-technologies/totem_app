import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

void main() {
  test('panel replacement and stale dismissal are atomic', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(sessionPresentationProvider.notifier);
    for (final panel in [
      SessionPanel.chat,
      SessionPanel.prompts,
      SessionPanel.admission,
    ]) {
      controller.openPanel(panel);
      final selected = container.read(sessionPresentationProvider);
      controller.openPanel(panel);
      check(
        container.read(sessionPresentationProvider).revision,
      ).equals(selected.revision);
      controller.closePanel(expectedRevision: selected.revision - 1);
      check(container.read(sessionPresentationProvider).panel).equals(panel);
      controller.togglePanel(panel);
      check(
        container.read(sessionPresentationProvider).panel,
      ).equals(SessionPanel.none);
    }
  });
  test('a replacement entry has fresh panels and unread threads', () {
    final root = ProviderContainer();
    addTearDown(root.dispose);
    ProviderContainer entry() => ProviderContainer(
      parent: root,
      overrides: [sessionScopeProvider.overrideWithValue(null)],
    );
    final first = entry();
    first
        .read(sessionPresentationProvider.notifier)
        .openPanel(SessionPanel.chat);
    first.read(sessionChatUnreadThreadsProvider.notifier).markUnread(null);
    final second = entry();
    addTearDown(second.dispose);
    check(
      second.read(sessionPresentationProvider).panel,
    ).equals(SessionPanel.none);
    check(second.read(sessionChatUnreadThreadsProvider)).isEmpty();
    first.dispose();
    second
        .read(sessionPresentationProvider.notifier)
        .openPanel(SessionPanel.prompts);
    check(
      second.read(sessionPresentationProvider).panel,
    ).equals(SessionPanel.prompts);
  });
}
