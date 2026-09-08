// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'message_peer_schema.dart';

@immutable
final class SessionParticipantSchema {
  const SessionParticipantSchema({
    required this.profile,
    required this.sessionsCount,
    this.reviewsCount,
  });

  factory SessionParticipantSchema.fromJson(Map<String, dynamic> json) {
    return SessionParticipantSchema(
      profile: MessagePeerSchema.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      sessionsCount: (json['sessions_count'] as num).toInt(),
      reviewsCount: json['reviews_count'] != null
          ? (json['reviews_count'] as num).toInt()
          : null,
    );
  }

  final MessagePeerSchema profile;

  final int sessionsCount;

  final int? reviewsCount;

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'sessions_count': sessionsCount,
      'reviews_count': ?reviewsCount,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('profile') &&
        json.containsKey('sessions_count') &&
        json['sessions_count'] is num;
  }

  SessionParticipantSchema copyWith({
    MessagePeerSchema? profile,
    int? sessionsCount,
    int? Function()? reviewsCount,
  }) {
    return SessionParticipantSchema(
      profile: profile ?? this.profile,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      reviewsCount: reviewsCount != null ? reviewsCount() : this.reviewsCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionParticipantSchema &&
            profile == other.profile &&
            sessionsCount == other.sessionsCount &&
            reviewsCount == other.reviewsCount;
  }

  @override
  int get hashCode {
    return Object.hash(profile, sessionsCount, reviewsCount);
  }

  @override
  String toString() {
    return 'SessionParticipantSchema(profile: $profile, sessionsCount: $sessionsCount, reviewsCount: $reviewsCount)';
  }
}
