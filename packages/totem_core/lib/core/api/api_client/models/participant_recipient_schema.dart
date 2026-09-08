// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'message_peer_schema.dart';

@immutable
final class ParticipantRecipientSchema {
  const ParticipantRecipientSchema({
    required this.profile,
    required this.existingConversationId,
    required this.canStartDirect,
    required this.sessionSlug,
    required this.sessionTitle,
    required this.sessionStart,
  });

  factory ParticipantRecipientSchema.fromJson(Map<String, dynamic> json) {
    return ParticipantRecipientSchema(
      profile: MessagePeerSchema.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      existingConversationId: json['existing_conversation_id'] as String?,
      canStartDirect: json['can_start_direct'] as bool,
      sessionSlug: json['session_slug'] as String,
      sessionTitle: json['session_title'] as String,
      sessionStart: DateTime.parse(json['session_start'] as String),
    );
  }

  final MessagePeerSchema profile;

  final String? existingConversationId;

  final bool canStartDirect;

  final String sessionSlug;

  final String sessionTitle;

  final DateTime sessionStart;

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'existing_conversation_id': ?existingConversationId,
      'can_start_direct': canStartDirect,
      'session_slug': sessionSlug,
      'session_title': sessionTitle,
      'session_start': sessionStart.toIso8601String(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('profile') &&
        json.containsKey('existing_conversation_id') &&
        json['existing_conversation_id'] is String &&
        json.containsKey('can_start_direct') &&
        json['can_start_direct'] is bool &&
        json.containsKey('session_slug') &&
        json['session_slug'] is String &&
        json.containsKey('session_title') &&
        json['session_title'] is String &&
        json.containsKey('session_start') &&
        json['session_start'] is String;
  }

  ParticipantRecipientSchema copyWith({
    MessagePeerSchema? profile,
    String? Function()? existingConversationId,
    bool? canStartDirect,
    String? sessionSlug,
    String? sessionTitle,
    DateTime? sessionStart,
  }) {
    return ParticipantRecipientSchema(
      profile: profile ?? this.profile,
      existingConversationId: existingConversationId != null
          ? existingConversationId()
          : this.existingConversationId,
      canStartDirect: canStartDirect ?? this.canStartDirect,
      sessionSlug: sessionSlug ?? this.sessionSlug,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      sessionStart: sessionStart ?? this.sessionStart,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ParticipantRecipientSchema &&
            profile == other.profile &&
            existingConversationId == other.existingConversationId &&
            canStartDirect == other.canStartDirect &&
            sessionSlug == other.sessionSlug &&
            sessionTitle == other.sessionTitle &&
            sessionStart == other.sessionStart;
  }

  @override
  int get hashCode {
    return Object.hash(
      profile,
      existingConversationId,
      canStartDirect,
      sessionSlug,
      sessionTitle,
      sessionStart,
    );
  }

  @override
  String toString() {
    return 'ParticipantRecipientSchema(profile: $profile, existingConversationId: $existingConversationId, canStartDirect: $canStartDirect, sessionSlug: $sessionSlug, sessionTitle: $sessionTitle, sessionStart: $sessionStart)';
  }
}
