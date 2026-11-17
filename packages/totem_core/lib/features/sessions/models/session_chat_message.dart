import 'dart:convert';

import 'package:totem_core/features/sessions/media/participant_info.dart';

class SessionChatMessage {
  const SessionChatMessage({
    required this.message,
    required this.timestamp,
    required this.id,
    required this.sender,
    this.participant,
    this.recipientIdentity,
  });

  factory SessionChatMessage.fromMap(
    Map<String, dynamic> map,
    ParticipantInfo? participant,
  ) {
    final recipient = map['recipientIdentity'] as String?;
    return SessionChatMessage(
      message: map['message'] as String,
      timestamp: map['timestamp'] as int,
      id: map['id'] as String,
      participant: participant,
      sender: false,
      // Older clients omit this key — treat that as the Everyone thread.
      recipientIdentity: (recipient == null || recipient.isEmpty)
          ? null
          : recipient,
    );
  }

  final String message;
  final int timestamp;
  final String id;
  final bool sender;
  final ParticipantInfo? participant;

  /// LiveKit identity of the private recipient. Null means Everyone.
  final String? recipientIdentity;

  /// [SessionChatMessage.fromMap] and every send-side caller normalize empty
  /// to null.
  bool get isEveryoneThread => recipientIdentity == null;

  String? threadTargetFor(String? localIdentity) {
    if (isEveryoneThread) return null;
    if (sender) return recipientIdentity;

    final senderId = participant?.identity;
    if (localIdentity != null &&
        senderId != null &&
        senderId == localIdentity) {
      return recipientIdentity;
    }
    return senderId;
  }

  /// Whether this message belongs in [threadTarget] for [localIdentity].
  ///
  /// [threadTarget] is null for Everyone. A private thread with X includes
  /// messages we sent to X and messages X sent to us.
  bool belongsToThread({
    required String? localIdentity,
    required String? threadTarget,
  }) {
    if (threadTarget == null) {
      return isEveryoneThread;
    }
    if (isEveryoneThread) {
      return false;
    }

    // [sender] is authoritative for locally-created messages: [participant] may
    // be null when the room isn't attached, and the UI's identity fallback
    // (slug/email) never matches a LiveKit identity.
    if (sender) {
      return recipientIdentity == threadTarget;
    }

    final senderId = participant?.identity;
    final recipientId = recipientIdentity;
    return (senderId == localIdentity && recipientId == threadTarget) ||
        (senderId == threadTarget && recipientId == localIdentity);
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'timestamp': timestamp,
      'id': id,
      if (recipientIdentity != null) 'recipientIdentity': recipientIdentity,
    };
  }

  String toJson() => const JsonEncoder().convert(toMap());
}
