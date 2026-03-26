import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:uuid/uuid.dart';

part 'session_messaging_controller.g.dart';

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

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),
  chat('lk-chat-topic'),
  participantRemoved('lk-participant-removed-topic');

  const SessionCommunicationTopics(this.topic);
  final String topic;
}

@Riverpod(keepAlive: true)
class SessionMessagingController extends _$SessionMessagingController {
  @override
  void build(SessionController session) {}

  SessionRoomState get _state => this.session.state;

  Room? get _room => this.session.room;

  void handleDataReceived(DataReceivedEvent event) {
    if (event.topic == SessionCommunicationTopics.emoji.topic) {
      final participant = event.participant;
      if (participant == null) return;
      final data = const Utf8Decoder().convert(event.data);
      ref
          .read(emojiReactionsProvider.notifier)
          .emitIncomingReaction(participant.identity, data);
      return;
    }

    if (event.topic == SessionCommunicationTopics.chat.topic) {
      final data = const Utf8Decoder().convert(event.data);
      try {
        final message = SessionChatMessage.fromMap(
          jsonDecode(data) as Map<String, dynamic>,
          event.participant,
        );
        this.session.addSessionChatMessage(message);
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error decoding chat message',
        );
      }
      return;
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
            event.participant!.identity != _state.roomState.keeper) {
          logger.d(
            'Participant removed event is not from the keeper, ignoring.',
          );
          return;
        }

        if (identity == _room?.localParticipant?.identity) {
          logger.d('Received participant removed event for local participant.');
          this.session.markParticipantRemoved();
          unawaited(this.session.disconnectFromRoom());
        }
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error decoding participant removed event',
        );
      }
      return;
    }

    return;
  }

  Future<void> sendReaction(String emoji) async {
    if (!_state.hasKeeper) {
      logger.w('Attempted to send reaction without a keeper, ignoring');
      return;
    }

    final room = _room;
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
    if (!this.session.isCurrentUserKeeper()) {
      logger.w(
        'Attempted to send chat message without being the keeper, ignoring',
      );
      return;
    }

    final room = _room;
    final message = SessionChatMessage(
      message: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      sender: true,
      participant: room?.localParticipant,
    );

    try {
      this.session.addSessionChatMessage(message);
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
