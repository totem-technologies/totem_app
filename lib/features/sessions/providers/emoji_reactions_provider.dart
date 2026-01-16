import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'emoji_reactions_provider.g.dart';

@riverpod
class EmojiReactions extends _$EmojiReactions {
  @override
  List<MapEntry<String, String>> build() => [];

  Future<void> addReaction(String userIdentity, String emoji) async {
    state = [...state, MapEntry(userIdentity, emoji)];

    await Future<void>.delayed(const Duration(seconds: 2));
    removeReaction(userIdentity, emoji);
  }

  void removeReaction(String userIdentity, String emoji) {
    state = state
        .where((entry) => entry.key != userIdentity || entry.value != emoji)
        .toList();
  }

  void clear() {
    state = [];
  }
}

@riverpod
List<String> participantEmojis(
  Ref ref,
  String participantIdentity,
) {
  final allReactions = ref.watch(emojiReactionsProvider);
  return [
    for (final entry in allReactions)
      if (entry.key == participantIdentity) entry.value,
  ];
}
