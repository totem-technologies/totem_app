import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';

part 'emoji_reactions_provider.g.dart';

@Riverpod(keepAlive: true)
class EmojiReactions extends _$EmojiReactions {
  static final emojiOverlayKey = GlobalKey<OverlayState>();

  final Map<String, DateTime> _lastReactionTimes = {};

  @override
  List<MapEntry<String, String>> build() => [];

  Future<void> addReaction(
    BuildContext context,
    String userIdentity,
    String emoji,
  ) async {
    final now = DateTime.now();
    final lastTime = _lastReactionTimes[userIdentity];

    // THROTTLE: If less than 0.3s has passed since this user's last emoji, ignore it.
    if (lastTime != null &&
        now.difference(lastTime) < const Duration(milliseconds: 300)) {
      return;
    }

    _lastReactionTimes[userIdentity] = now;

    final entry = MapEntry(userIdentity, emoji);
    final newState = [...state, entry];
    if (newState.length > 10) {
      newState.removeAt(0);
    }
    state = newState;

    try {
      await displayReaction(
        context,
        emoji,
        overlayKey: EmojiReactions.emojiOverlayKey,
      );
    } finally {
      state = state.where((e) => e != entry).toList();
    }
  }

  void clear() {
    state = [];
    _lastReactionTimes.clear();
  }
}

@riverpod
List<String> participantEmojis(
  Ref ref,
  String participantIdentity,
) {
  return ref.watch(
    emojiReactionsProvider.select(
      (reactions) => reactions
          .where((entry) => entry.key == participantIdentity)
          .map((e) => e.value)
          .toList(),
    ),
  );
}
