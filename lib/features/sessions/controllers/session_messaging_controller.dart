import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide logger, ChatMessage;
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/session_types.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/shared/logger.dart';

class SessionMessagingController {
  SessionMessagingController({
    required this.ref,
    required this.currentRoom,
    required this.currentKeeperIdentity,
    required this.hasKeeper,
    required this.isCurrentUserKeeper,
    required this.onChatMessage,
    required this.onLocalParticipantRemoved,
    required this.disconnect,
  });

  final Ref ref;
  final CurrentRoomGetter currentRoom;
  final CurrentKeeperIdentityGetter currentKeeperIdentity;
  final BoolGetter hasKeeper;
  final BoolGetter isCurrentUserKeeper;
  final MessageCallback<ChatMessage> onChatMessage;
  final VoidCallback onLocalParticipantRemoved;
  final AsyncCallback disconnect;

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

    if (event.topic == SessionCommunicationTopics.participantRemoved.topic) {
      final data = const Utf8Decoder().convert(event.data);
      logger.d(
        'Received participant removed event from ${event.participant?.identity}: $data',
      );

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final identity = json['identity'] as String?;

        // If participant identity is null, message is server-originated.
        if (event.participant?.identity != null &&
            event.participant!.identity != currentKeeperIdentity()) {
          logger.d(
            'Participant removed event is not from the keeper, ignoring.',
          );
          return true;
        }

        if (identity == currentRoom()?.localParticipant?.identity) {
          logger.d('Received participant removed event for local participant.');
          onLocalParticipantRemoved();
          unawaited(disconnect());
        }
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error decoding participant removed event',
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
