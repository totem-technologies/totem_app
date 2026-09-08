// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'message_peer_schema.dart';

@immutable
final class KeeperRecipientSchema {
  const KeeperRecipientSchema({
    required this.profile,
    required this.existingConversationId,
    required this.canStartDirect,
  });

  factory KeeperRecipientSchema.fromJson(Map<String, dynamic> json) {
    return KeeperRecipientSchema(
      profile: MessagePeerSchema.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      existingConversationId: json['existing_conversation_id'] as String?,
      canStartDirect: json['can_start_direct'] as bool,
    );
  }

  final MessagePeerSchema profile;

  final String? existingConversationId;

  final bool canStartDirect;

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'existing_conversation_id': ?existingConversationId,
      'can_start_direct': canStartDirect,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('profile') &&
        json.containsKey('existing_conversation_id') &&
        json['existing_conversation_id'] is String &&
        json.containsKey('can_start_direct') &&
        json['can_start_direct'] is bool;
  }

  KeeperRecipientSchema copyWith({
    MessagePeerSchema? profile,
    String? Function()? existingConversationId,
    bool? canStartDirect,
  }) {
    return KeeperRecipientSchema(
      profile: profile ?? this.profile,
      existingConversationId: existingConversationId != null
          ? existingConversationId()
          : this.existingConversationId,
      canStartDirect: canStartDirect ?? this.canStartDirect,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KeeperRecipientSchema &&
            profile == other.profile &&
            existingConversationId == other.existingConversationId &&
            canStartDirect == other.canStartDirect;
  }

  @override
  int get hashCode {
    return Object.hash(profile, existingConversationId, canStartDirect);
  }

  @override
  String toString() {
    return 'KeeperRecipientSchema(profile: $profile, existingConversationId: $existingConversationId, canStartDirect: $canStartDirect)';
  }
}
