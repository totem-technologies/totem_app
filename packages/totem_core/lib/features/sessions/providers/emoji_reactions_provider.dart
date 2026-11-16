import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/models/session_emoji_reaction.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/services/session_reaction_buffer.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_core/shared/utils.dart';

export 'package:totem_core/features/sessions/models/session_emoji_reaction.dart';

part 'emoji_reactions_provider.g.dart';

final emojiReactionClockProvider = Provider<ValueGetter<DateTime>>(
  (ref) => DateTime.timestamp,
);

@Riverpod(keepAlive: true, dependencies: [currentSession])
class EmojiReactions extends _$EmojiReactions {
  static final emojiOverlayKey = GlobalKey<OverlayState>();

  late SessionReactionBuffer _buffer;
  @override
  List<SessionEmojiReaction> build() {
    final owned = ref.watch(currentSessionProvider)?.reactionBuffer;
    final buffer = _buffer =
        owned ??
        SessionReactionBuffer(now: ref.read(emojiReactionClockProvider));
    void update() {
      if (ref.mounted) state = buffer.reactions;
    }

    buffer.addListener(update);
    ref.onDispose(() {
      buffer.removeListener(update);
      if (owned == null) buffer.dispose();
    });
    return buffer.reactions;
  }

  Future<bool> emitIncomingReaction(String identity, String emoji) =>
      _buffer.emitIncomingReaction(identity, emoji);

  Future<void> displayReaction(
    BuildContext context,
    SessionEmojiReaction reaction,
    bool isInListeningTurnScreen, {

    /// The minimum amount of time the reaction will live before being removed.
    Duration minAliveDuration = const Duration(milliseconds: 4000),
  }) async {
    final buffer = _buffer;
    // While the app is hidden (e.g. a backgrounded browser tab) no frames
    // are rendered, so overlay entries would accumulate unbuilt and all
    // animate at once on refocus. Nobody can see the reaction anyway.
    if (isAppHidden()) {
      buffer.remove(reaction);
      return;
    }

    buffer.markDisplayed(reaction);
    try {
      await Future.wait([
        presentEmojiReaction(
          context,
          reaction.emoji,
          overlayKey: EmojiReactions.emojiOverlayKey,
          isInListeningTurnScreen: isInListeningTurnScreen,
        ),
        Future<void>.delayed(minAliveDuration),
      ]);
    } finally {
      buffer.remove(reaction);
    }
  }

  void clear() {
    _buffer.clear();
  }
}

@Riverpod(dependencies: [EmojiReactions])
List<String> participantEmojis(Ref ref, String participantIdentity) {
  return ref.watch(
    emojiReactionsProvider.select(
      (reactions) => reactions
          .where((entry) => entry.userIdentity == participantIdentity)
          .map((e) => e.emoji)
          .toList(),
    ),
  );
}
