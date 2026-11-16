import 'package:flutter/foundation.dart';

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
