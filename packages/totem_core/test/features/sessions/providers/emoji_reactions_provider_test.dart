import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';

void main() {
  group('EmojiReactions Provider', () {
    late ProviderContainer container;
    late DateTime now;

    setUp(() {
      now = DateTime.utc(2026);
      container = ProviderContainer(
        overrides: [emojiReactionClockProvider.overrideWithValue(() => now)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(emojiReactionsProvider);
      check(state).isEmpty();
    });

    test('emitIncomingReaction adds a reaction', () async {
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👍');

      final state = container.read(emojiReactionsProvider);
      check(state).length.equals(1);
      check(state.first.userIdentity).equals('user1');
      check(state.first.emoji).equals('👍');
      check(state.first.displayed).equals(false);
    });

    test(
      'emitIncomingReaction throttles rapid reactions from same user',
      () async {
        final notifier = container.read(emojiReactionsProvider.notifier);

        await notifier.emitIncomingReaction('user1', '👍');
        await notifier.emitIncomingReaction('user1', '❤️');

        final state = container.read(emojiReactionsProvider);
        check(state).length.equals(1);
        check(state.first.emoji).equals('👍');
      },
    );

    test(
      'emitIncomingReaction allows reaction after throttle duration',
      () async {
        final notifier = container.read(emojiReactionsProvider.notifier);

        await notifier.emitIncomingReaction('user1', '👍');

        now = now.add(const Duration(milliseconds: 310));

        await notifier.emitIncomingReaction('user1', '❤️');

        final state = container.read(emojiReactionsProvider);
        check(state).length.equals(2);
        check(state[0].emoji).equals('👍');
        check(state[1].emoji).equals('❤️');
      },
    );

    test('emitIncomingReaction does not throttle different users', () async {
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👍');
      await notifier.emitIncomingReaction('user2', '❤️');

      final state = container.read(emojiReactionsProvider);
      check(state).length.equals(2);
    });

    test('emitIncomingReaction limits history to 10 items (FIFO)', () async {
      final notifier = container.read(emojiReactionsProvider.notifier);

      for (int i = 0; i < 11; i++) {
        await notifier.emitIncomingReaction('user1', 'emoji_$i');
        now = now.add(const Duration(milliseconds: 310));
      }

      final state = container.read(emojiReactionsProvider);
      check(state).length.equals(10);
      check(state.first.emoji).equals('emoji_1');
      check(state.last.emoji).equals('emoji_10');
    });
  });

  group('participantEmojis Provider', () {
    test('filters emojis by participant identity', () async {
      var now = DateTime.utc(2026);
      final container = ProviderContainer(
        overrides: [emojiReactionClockProvider.overrideWithValue(() => now)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👍');
      await notifier.emitIncomingReaction('user2', '❤️');
      now = now.add(const Duration(milliseconds: 310));
      await notifier.emitIncomingReaction('user1', '🔥');

      final user1Emojis = container.read(participantEmojisProvider('user1'));
      final user2Emojis = container.read(participantEmojisProvider('user2'));
      final user3Emojis = container.read(participantEmojisProvider('user3'));

      check(user1Emojis).deepEquals(['👍', '🔥']);
      check(user2Emojis).deepEquals(['❤️']);
      check(user3Emojis).isEmpty();
    });
  });

  group('EmojiReactions Display Logic', () {
    Future<ProviderContainer> pumpOverlayHost(WidgetTester tester) async {
      final initialEntry = OverlayEntry(builder: (context) => const SizedBox());
      addTearDown(() async {
        initialEntry.remove();
        initialEntry.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Overlay(
              key: EmojiReactions.emojiOverlayKey,
              initialEntries: [initialEntry],
            ),
          ),
        ),
      );

      final element = tester.element(
        find.byKey(EmojiReactions.emojiOverlayKey),
      );
      return ProviderScope.containerOf(element);
    }

    testWidgets('displayReaction updates state lifecycle', (tester) async {
      final container = await pumpOverlayHost(tester);

      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👍');
      var state = container.read(emojiReactionsProvider);
      check(state).length.equals(1);
      final reaction = state.first;
      check(reaction.displayed).equals(false);

      final context = tester.element(
        find.byKey(EmojiReactions.emojiOverlayKey),
      );

      final future = notifier.displayReaction(context, reaction, false);

      state = container.read(emojiReactionsProvider);
      check(
        because: 'Should be marked displayed while animating',
        state.first.displayed,
      ).equals(true);

      await tester.pumpAndSettle(const Duration(seconds: 4));
      await future;

      state = container.read(emojiReactionsProvider);
      check(
        because: 'Should be removed after display is done',
        state,
      ).isEmpty();
    });

    testWidgets('displayReaction renders emoji on screen while animating', (
      tester,
    ) async {
      final container = await pumpOverlayHost(tester);
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '🔥');
      final reaction = container.read(emojiReactionsProvider).first;

      final context = tester.element(
        find.byKey(EmojiReactions.emojiOverlayKey),
      );

      final future = notifier.displayReaction(context, reaction, false);
      await tester.pump();

      check(tester.widgetList(find.text('🔥'))).length.equals(1);

      await tester.pumpAndSettle(const Duration(seconds: 4));
      await future;
      check(tester.widgetList(find.text('🔥'))).length.equals(0);
    });

    testWidgets('displayReaction drops the reaction while the app is hidden', (
      tester,
    ) async {
      final container = await pumpOverlayHost(tester);
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👏');
      final reaction = container.read(emojiReactionsProvider).first;

      final context = tester.element(
        find.byKey(EmojiReactions.emojiOverlayKey),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      try {
        await notifier.displayReaction(context, reaction, false);

        check(
          because: 'Hidden app should drop the reaction without presenting it',
          container.read(emojiReactionsProvider),
        ).isEmpty();
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }

      await tester.pump();
      check(
        because: 'No overlay entry should be queued for when the app resumes',
        tester.widgetList(find.text('👏')),
      ).length.equals(0);
    });

    testWidgets('displayReaction renders emoji in not-my-turn mode too', (
      tester,
    ) async {
      final container = await pumpOverlayHost(tester);
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '🎉');
      final reaction = container.read(emojiReactionsProvider).first;

      final context = tester.element(
        find.byKey(EmojiReactions.emojiOverlayKey),
      );

      final future = notifier.displayReaction(context, reaction, true);
      await tester.pump();

      check(tester.widgetList(find.text('🎉'))).length.equals(1);

      await tester.pumpAndSettle(const Duration(seconds: 4));
      await future;
      check(tester.widgetList(find.text('🎉'))).length.equals(0);
    });
  });
}
