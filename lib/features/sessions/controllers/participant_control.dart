// We need to access SessionService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'session_controller.dart';

class ChatMessage {
  const ChatMessage({
    required this.message,
    required this.timestamp,
    required this.id,
    required this.sender,
    this.participant,
  });

  factory ChatMessage.fromMap(
    Map<String, dynamic> map,
    Participant? participant,
  ) {
    return ChatMessage(
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

extension ParticipantControl on SessionController {
  /// Pass the totem to the next participant in the speaking order.
  ///
  /// Throws an exception if the operation fails.
  Future<void> passTotem({String? roundMessage}) =>
      _totem.passTotem(roundMessage: roundMessage);

  /// Accept the totem when it's passed to the user.
  ///
  /// This fails silently if it's not the user's turn.
  /// Throws an exception if the operation fails.
  Future<void> acceptTotem() => _totem.acceptTotem();

  /// Send an emoji to other participants.
  /// This operation is fire-and-forget and doesn't throw errors.
  Future<void> sendReaction(String emoji) => _chat.sendReaction(emoji);

  /// Send a chat message to other participants.
  ///
  /// Only the keeper can send chat messages, and this method will fail silently if the user is not the keeper.
  ///
  /// This operation is fire-and-forget and doesn't throw errors.
  Future<void> sendMessage(String text) => _chat.sendMessage(text);
}
