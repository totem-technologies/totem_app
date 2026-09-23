// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'message_peer_schema.dart';

@immutable
final class SessionParticipantSchema {
  const SessionParticipantSchema({
    required this.profile,
    required this.sessionsCount,
  });

  factory SessionParticipantSchema.fromJson(Map<String, dynamic> json) {
    return SessionParticipantSchema(
      profile: MessagePeerSchema.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      sessionsCount: (json['sessions_count'] as num).toInt(),
    );
  }

  final MessagePeerSchema profile;

  final int sessionsCount;

  Map<String, dynamic> toJson() {
    return {'profile': profile.toJson(), 'sessions_count': sessionsCount};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('profile') &&
        json.containsKey('sessions_count') &&
        json['sessions_count'] is num;
  }

  SessionParticipantSchema copyWith({
    MessagePeerSchema? profile,
    int? sessionsCount,
  }) {
    return SessionParticipantSchema(
      profile: profile ?? this.profile,
      sessionsCount: sessionsCount ?? this.sessionsCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionParticipantSchema &&
            profile == other.profile &&
            sessionsCount == other.sessionsCount;
  }

  @override
  int get hashCode {
    return Object.hash(profile, sessionsCount);
  }

  @override
  String toString() {
    return 'SessionParticipantSchema(profile: $profile, sessionsCount: $sessionsCount)';
  }
}
