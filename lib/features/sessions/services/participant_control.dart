// We need to access SessionService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'session_service.dart';

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

extension ParticipantControl on Session {
  /// Pass the totem to the next participant in the speaking order.
  ///
  /// This fails silently if it's not the user's turn.
  /// Throws an exception if the operation fails.
  Future<void> passTotem() async {
    if (!isCurrentUserKeeper() && !state.isMyTurn(room!)) return;
    disableMicrophone();
    try {
      final roomState = await ref.read(
        passTotemProvider(
          options.eventSlug,
          state.roomState.version,
        ).future,
      );
      _onRoomChanges(roomState);
      logger.i('Passed totem successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error passing totem',
      );
      rethrow;
    }
  }

  /// Accept the totem when it's passed to the user.
  ///
  /// This fails silently if it's not the user's turn.
  /// Throws an exception if the operation fails.
  Future<void> acceptTotem() async {
    if (!isCurrentUserKeeper() && !state.amNext(room!)) {
      throw StateError("Not the user's turn to accept the totem");
    }
    try {
      final roomState = await ref.read(
        acceptTotemProvider(
          options.eventSlug,
          state.roomState.version,
        ).future,
      );
      _onRoomChanges(roomState);
      enableMicrophone();
      logger.i('Accepted totem successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error accepting totem',
      );
      rethrow;
    }
  }

  /// Send an emoji to other participants.
  /// This operation is fire-and-forget and doesn't throw errors.
  Future<void> sendReaction(String emoji) async {
    ref
        .read(emojiReactionsProvider.notifier)
        .emitIncomingReaction(
          room?.localParticipant?.identity ?? 'unknown',
          emoji,
        );
    try {
      await room?.localParticipant
          ?.publishData(
            const Utf8Encoder().convert(emoji),
            topic: SessionCommunicationTopics.emoji.topic,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              ErrorHandler.logError(
                TimeoutException('Sending emoji timed out'),
                message: 'Warning: Sending emoji timed out',
              );
            },
          );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error sending emoji',
      );
    }
  }

  /// Send a chat message to other participants.
  /// This operation is fire-and-forget and doesn't throw errors.
  Future<void> sendMessage(String text) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final message = ChatMessage(
      message: text,
      timestamp: timestamp,
      id: timestamp.toString(),
      sender: true,
      participant: room?.localParticipant,
    );
    try {
      state = state.copyWith(messages: [...state.messages, message]);
      await room?.localParticipant
          ?.publishData(
            const Utf8Encoder().convert(message.toJson()),
            topic: SessionCommunicationTopics.chat.topic,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              ErrorHandler.logError(
                TimeoutException('Sending chat message timed out'),
                message: 'Warning: Sending chat message timed out',
              );
            },
          );
    } catch (error, stackTrace) {
      // TODO(bdlukaa): Mark message as failed.
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error sending chat message',
      );
    }
  }
}
