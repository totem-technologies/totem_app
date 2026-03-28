import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';
import 'package:uuid/uuid.dart';

part 'emoji_reactions_provider.g.dart';

@immutable
class SessionEmojiReaction {
  const SessionEmojiReaction({
    required this.timestamp,
    required this.userIdentity,
    required this.emoji,
    required this.eventId,
    required this.displayed,
  });

  final DateTime timestamp;
  final String userIdentity;
  final String emoji;
  final String eventId;
  final bool displayed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionEmojiReaction && other.eventId == eventId;
  }

  @override
  int get hashCode => eventId.hashCode;

  SessionEmojiReaction copyWith({
    DateTime? timestamp,
    String? userIdentity,
    String? emoji,
    String? eventId,
    bool? displayed,
  }) {
    return SessionEmojiReaction(
      timestamp: timestamp ?? this.timestamp,
      userIdentity: userIdentity ?? this.userIdentity,
      emoji: emoji ?? this.emoji,
      eventId: eventId ?? this.eventId,
      displayed: displayed ?? this.displayed,
    );
  }
}

@Riverpod(keepAlive: true)
class EmojiReactions extends _$EmojiReactions {
  static final emojiOverlayKey = GlobalKey<OverlayState>();

  @override
  List<SessionEmojiReaction> build() => <SessionEmojiReaction>[];

  Future<void> emitIncomingReaction(
    String userIdentity,
    String emoji,
  ) async {
    final now = DateTime.timestamp();
    final lastTime = state
        .lastWhereOrNull(
          (r) => r.userIdentity == userIdentity,
        )
        ?.timestamp;

    // THROTTLE: If less than 0.3s has passed since this user's last emoji, ignore it.
    if (lastTime != null &&
        now.difference(lastTime) < const Duration(milliseconds: 300)) {
      return;
    }

    final entry = SessionEmojiReaction(
      timestamp: now,
      userIdentity: userIdentity,
      emoji: emoji,
      eventId: const Uuid().v1(),
      displayed: false,
    );

    final newState = <SessionEmojiReaction>[
      ...state,
      entry,
    ];
    if (newState.length > 10) {
      newState.removeAt(0);
    }
    state = newState;
  }

  Future<void> displayReaction(
    BuildContext context,
    SessionEmojiReaction reaction,
    bool isInNotMyTurnScreen,
  ) async {
    state = state
        .map((r) => r == reaction ? r.copyWith(displayed: true) : r)
        .toList();
    try {
      await presentEmojiReaction(
        context,
        reaction.emoji,
        overlayKey: EmojiReactions.emojiOverlayKey,
        isInNotMyTurnScreen: isInNotMyTurnScreen,
      );
    } finally {
      state = state.where((e) => e != reaction).toList();
    }
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
  return ref.watch(
    emojiReactionsProvider.select(
      (reactions) => reactions
          .where((entry) => entry.userIdentity == participantIdentity)
          .map((e) => e.emoji)
          .toList(),
    ),
  );
}
