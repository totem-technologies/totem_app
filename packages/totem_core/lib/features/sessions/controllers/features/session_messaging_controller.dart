import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/shared/logger.dart';
import 'package:uuid/uuid.dart';

part 'session_messaging_controller.g.dart';

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
    Participant? participant,
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
  final Participant? participant;

  /// LiveKit identity of the private recipient. Null means Everyone.
  final String? recipientIdentity;

  bool get isEveryoneThread =>
      recipientIdentity == null || recipientIdentity!.isEmpty;

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

  SessionRoomState get _state => session.state;

  Room? get _room => session.room;

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

        // Everyone is keeper-broadcast only. Drop group posts from anyone else
        // so a stale or malicious client cannot write into the main thread.
        final senderId = event.participant?.identity;
        if (message.isEveryoneThread &&
            senderId != null &&
            senderId != _state.roomState.keeper) {
          logger.w(
            'Ignoring Everyone chat message from non-keeper $senderId',
          );
          return;
        }

        session.addSessionChatMessage(message);
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
        // If participant identity is null, message is server-originated.
        if (event.participant?.identity != null &&
            event.participant?.identity != _state.roomState.keeper) {
          logger.d(
            'Participant removed event is not from the keeper, ignoring.',
          );
          return;
        }

        final json = jsonDecode(data) as Map<String, dynamic>;
        final payload = RemoveParticipantPayload.fromJson(json);

        if (payload.identity == _room?.localParticipant?.identity) {
          logger.d(
            'Received participant removed event for local participant. '
            'Reason: ${payload.reason.value}',
          );
          session.markParticipantRemoved(payload.reason);
          unawaited(session.disconnectFromRoom());
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

  /// Sends [text] to Everyone when [recipientIdentity] is null, or as a
  /// private LiveKit data message when a recipient is set.
  ///
  /// Everyone is keeper-only. Participants may only DM the keeper.
  Future<void> sendMessage(
    String text, {
    String? recipientIdentity,
  }) async {
    final isKeeper = session.isCurrentUserKeeper();
    final keeperIdentity = _state.roomState.keeper;
    final localIdentity = _room?.localParticipant?.identity;
    final trimmedRecipient =
        (recipientIdentity == null || recipientIdentity.isEmpty)
        ? null
        : recipientIdentity;

    if (trimmedRecipient == null) {
      if (!isKeeper) {
        logger.w(
          'Attempted to send an Everyone chat message without being the '
          'keeper, ignoring',
        );
        return;
      }
    } else if (isKeeper) {
      if (trimmedRecipient == localIdentity) {
        logger.w('Keeper attempted to DM themselves, ignoring');
        return;
      }
    } else if (trimmedRecipient != keeperIdentity) {
      logger.w(
        'Participant attempted to DM $trimmedRecipient instead of the '
        'keeper, ignoring',
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
      recipientIdentity: trimmedRecipient,
    );

    try {
      session.addSessionChatMessage(message);
      await room?.localParticipant
          ?.publishData(
            const Utf8Encoder().convert(message.toJson()),
            topic: SessionCommunicationTopics.chat.topic,
            // LiveKit delivers private payloads only to this identity.
            destinationIdentities: trimmedRecipient == null
                ? null
                : [trimmedRecipient],
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
