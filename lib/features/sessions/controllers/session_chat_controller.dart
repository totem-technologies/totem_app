import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide logger, ChatMessage;
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/session_controller.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/shared/logger.dart';

class SessionChatController {
  SessionChatController({
    required this.ref,
    required this.currentRoom,
    required this.hasKeeper,
    required this.isCurrentUserKeeper,
    required this.onChatMessage,
  });

  final Ref ref;
  final Room? Function() currentRoom;
  final bool Function() hasKeeper;
  final bool Function() isCurrentUserKeeper;
  final void Function(ChatMessage message) onChatMessage;

  bool handleDataReceived(DataReceivedEvent event) {
    if (event.topic == SessionCommunicationTopics.emoji.topic) {
      final participant = event.participant;
      if (participant == null) return true;
      final data = const Utf8Decoder().convert(event.data);
      ref
          .read(emojiReactionsProvider.notifier)
          .emitIncomingReaction(participant.identity, data);
      return true;
    }

    if (event.topic == SessionCommunicationTopics.chat.topic) {
      final data = const Utf8Decoder().convert(event.data);
      try {
        final message = ChatMessage.fromMap(
          jsonDecode(data) as Map<String, dynamic>,
          event.participant,
        );
        onChatMessage(message);
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error decoding chat message',
        );
      }
      return true;
    }

    return false;
  }

  Future<void> sendReaction(String emoji) async {
    if (!hasKeeper()) {
      logger.w('Attempted to send reaction without a keeper, ignoring');
      return;
    }

    final room = currentRoom();
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

  Future<void> sendMessage(String text) async {
    if (!isCurrentUserKeeper()) {
      logger.w(
        'Attempted to send chat message without being the keeper, ignoring',
      );
      return;
    }

    final room = currentRoom();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final message = ChatMessage(
      message: text,
      timestamp: timestamp,
      id: timestamp.toString(),
      sender: true,
      participant: room?.localParticipant,
    );

    try {
      onChatMessage(message);
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
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error sending chat message',
      );
    }
  }
}
