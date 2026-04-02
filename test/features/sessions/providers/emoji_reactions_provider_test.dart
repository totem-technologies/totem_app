import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';

void main() {
  group('EmojiReactions Provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(emojiReactionsProvider);
      expect(state, isEmpty);
    });

    test('emitIncomingReaction adds a reaction', () async {
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👍');

      final state = container.read(emojiReactionsProvider);
      expect(state, hasLength(1));
      expect(state.first.userIdentity, 'user1');
      expect(state.first.emoji, '👍');
      expect(state.first.displayed, isFalse);
    });

    test(
      'emitIncomingReaction throttles rapid reactions from same user',
      () async {
        final notifier = container.read(emojiReactionsProvider.notifier);

        await notifier.emitIncomingReaction('user1', '👍');
        await notifier.emitIncomingReaction('user1', '❤️');

        final state = container.read(emojiReactionsProvider);
        expect(state, hasLength(1));
        expect(state.first.emoji, '👍');
      },
    );

    test(
      'emitIncomingReaction allows reaction after throttle duration',
      () async {
        final notifier = container.read(emojiReactionsProvider.notifier);

        await notifier.emitIncomingReaction('user1', '👍');

        await Future<void>.delayed(const Duration(milliseconds: 310));

        await notifier.emitIncomingReaction('user1', '❤️');

        final state = container.read(emojiReactionsProvider);
        expect(state, hasLength(2));
        expect(state[0].emoji, '👍');
        expect(state[1].emoji, '❤️');
      },
    );

    test('emitIncomingReaction does not throttle different users', () async {
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👍');
      await notifier.emitIncomingReaction('user2', '❤️');

      final state = container.read(emojiReactionsProvider);
      expect(state, hasLength(2));
    });

    test('emitIncomingReaction limits history to 10 items (FIFO)', () async {
      final notifier = container.read(emojiReactionsProvider.notifier);

      for (int i = 0; i < 11; i++) {
        await notifier.emitIncomingReaction('user1', 'emoji_$i');
        await Future<void>.delayed(const Duration(milliseconds: 310));
      }

      final state = container.read(emojiReactionsProvider);
      expect(state, hasLength(10));
      expect(state.first.emoji, 'emoji_1');
      expect(state.last.emoji, 'emoji_10');
    });
  });

  group('participantEmojis Provider', () {
    test('filters emojis by participant identity', () async {
      final container = ProviderContainer();
      final notifier = container.read(emojiReactionsProvider.notifier);

      await notifier.emitIncomingReaction('user1', '👍');
      await notifier.emitIncomingReaction('user2', '❤️');
      await Future<void>.delayed(const Duration(milliseconds: 310));
      await notifier.emitIncomingReaction('user1', '🔥');

      final user1Emojis = container.read(participantEmojisProvider('user1'));
      final user2Emojis = container.read(participantEmojisProvider('user2'));
      final user3Emojis = container.read(participantEmojisProvider('user3'));

      expect(user1Emojis, ['👍', '🔥']);
      expect(user2Emojis, ['❤️']);
      expect(user3Emojis, isEmpty);
    });
  });

  group('EmojiReactions Display Logic', () {
    Future<ProviderContainer> pumpOverlayHost(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Overlay(
              key: EmojiReactions.emojiOverlayKey,
              initialEntries: [
                OverlayEntry(builder: (context) => const SizedBox()),
              ],
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
      expect(state, hasLength(1));
      final reaction = state.first;
      expect(reaction.displayed, isFalse);

      final context = tester.element(
        find.byKey(EmojiReactions.emojiOverlayKey),
      );

      final future = notifier.displayReaction(context, reaction, false);

      state = container.read(emojiReactionsProvider);
      expect(
        state.first.displayed,
        isTrue,
        reason: 'Should be marked displayed while animating',
      );

      await tester.pumpAndSettle(const Duration(seconds: 4));
      await future;

      state = container.read(emojiReactionsProvider);
      expect(state, isEmpty, reason: 'Should be removed after display is done');
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

      expect(find.text('🔥'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 4));
      await future;
      expect(find.text('🔥'), findsNothing);
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

      expect(find.text('🎉'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 4));
      await future;
      expect(find.text('🎉'), findsNothing);
    });
  });
}
