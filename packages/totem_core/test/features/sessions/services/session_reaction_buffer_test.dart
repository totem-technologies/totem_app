import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/services/session_reaction_buffer.dart';

class _Session extends Mock implements SessionController {
  _Session(this.buffer);
  final SessionReactionBuffer buffer;
  @override
  SessionReactionBuffer? get reactionBuffer => buffer;
}

void main() {
  test(
    'session entries own independent throttle windows and reaction history',
    () async {
      var now = DateTime.utc(2026);
      var nextId = 0;
      final first = SessionReactionBuffer(
        now: () => now,
        createId: () => 'first-${nextId++}',
      );
      final second = SessionReactionBuffer(
        now: () => now,
        createId: () => 'second-${nextId++}',
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      check(await first.emitIncomingReaction('participant', '👍')).isTrue();
      check(await second.emitIncomingReaction('participant', '❤️')).isTrue();
      check(await first.emitIncomingReaction('participant', '🔥')).isFalse();
      check(
        first.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['👍']);
      check(
        second.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['❤️']);

      first.clear();
      check(first.reactions).isEmpty();
      check(
        second.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['❤️']);
      check(await first.emitIncomingReaction('participant', '🔥')).isTrue();
      check(await second.emitIncomingReaction('participant', '🔥')).isFalse();
      now = now.add(const Duration(milliseconds: 310));
      check(await second.emitIncomingReaction('participant', '🔥')).isTrue();
      check(
        second.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['❤️', '🔥']);
    },
  );

  test(
    'reaction snapshots cannot be mutated or changed by later emissions',
    () async {
      var now = DateTime.utc(2026);
      var nextId = 0;
      final buffer = SessionReactionBuffer(
        now: () => now,
        createId: () => 'reaction-${nextId++}',
      );
      addTearDown(buffer.dispose);
      await buffer.emitIncomingReaction('participant', '👍');
      final snapshot = buffer.reactions;
      now = now.add(const Duration(milliseconds: 310));
      await buffer.emitIncomingReaction('participant', '❤️');

      check(snapshot.map((reaction) => reaction.emoji)).deepEquals(['👍']);
      check(
        buffer.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['👍', '❤️']);
      check(snapshot.clear).throws<UnsupportedError>();
      check(
        () => buffer.reactions.add(snapshot.single),
      ).throws<UnsupportedError>();
      buffer.clear();
      check(snapshot.map((reaction) => reaction.emoji)).deepEquals(['👍']);
      check(buffer.reactions).isEmpty();
    },
  );

  test(
    'the projection follows session replacement and ignores late events from the old entry',
    () async {
      final firstBuffer = SessionReactionBuffer(
        now: () => DateTime.utc(2026),
        createId: () => 'first',
      );
      final secondBuffer = SessionReactionBuffer(
        now: () => DateTime.utc(2026),
        createId: () => 'second',
      );
      addTearDown(firstBuffer.dispose);
      addTearDown(secondBuffer.dispose);
      final first = _Session(firstBuffer);
      final second = _Session(secondBuffer);
      final container = ProviderContainer(
        overrides: [currentSessionProvider.overrideWithValue(first)],
      );
      addTearDown(container.dispose);
      var updates = 0;
      final subscription = container.listen(emojiReactionsProvider, (_, _) {
        updates++;
      });
      addTearDown(subscription.close);
      await firstBuffer.emitIncomingReaction('participant', '👍');
      check(
        container
            .read(emojiReactionsProvider)
            .map((reaction) => reaction.emoji),
      ).deepEquals(['👍']);

      container.updateOverrides([
        currentSessionProvider.overrideWithValue(second),
      ]);
      await container.pump();
      check(container.read(currentSessionProvider)).identicalTo(second);
      check(container.read(emojiReactionsProvider)).isEmpty();
      await secondBuffer.emitIncomingReaction('participant', '❤️');
      final secondSnapshot = container.read(emojiReactionsProvider);
      final updatesBeforeOldEvents = updates;
      await firstBuffer.emitIncomingReaction('late-participant', '🔥');
      firstBuffer.clear();
      await container.pump();

      check(container.read(emojiReactionsProvider)).identicalTo(secondSnapshot);
      check(
        secondSnapshot.map((reaction) => reaction.emoji),
      ).deepEquals(['❤️']);
      check(updates).equals(updatesBeforeOldEvents);
    },
  );

  test(
    'disposing the presentation projection leaves the session-owned buffer usable',
    () async {
      final buffer = SessionReactionBuffer(
        now: () => DateTime.utc(2026),
        createId: () => 'reaction',
      );
      addTearDown(buffer.dispose);
      final session = _Session(buffer);
      final container = ProviderContainer(
        overrides: [currentSessionProvider.overrideWith((_) => session)],
      );
      final subscription = container.listen(emojiReactionsProvider, (_, _) {});
      await buffer.emitIncomingReaction('participant', '👍');
      check(container.read(emojiReactionsProvider)).length.equals(1);

      subscription.close();
      container.dispose();
      check(
        await buffer.emitIncomingReaction('another-participant', '❤️'),
      ).isTrue();
      check(
        buffer.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['👍', '❤️']);
    },
  );
}
