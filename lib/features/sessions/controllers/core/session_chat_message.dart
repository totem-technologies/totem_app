import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' hide logger;

class SessionChatMessage {
  const SessionChatMessage({
    required this.message,
    required this.timestamp,
    required this.id,
    required this.sender,
    this.participant,
  });

  factory SessionChatMessage.fromMap(
    Map<String, dynamic> map,
    Participant? participant,
  ) {
    return SessionChatMessage(
      message: map['message'] as String,
      timestamp: map['timestamp'] as int,
      id: map['id'] as String,
      participant: participant,
      sender: false,
    );
  }

  final String message;
  final int timestamp;
  final String id;
  final bool sender;
  final Participant? participant;

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'timestamp': timestamp,
      'id': id,
    };
  }

  String toJson() => const JsonEncoder().convert(toMap());
}
