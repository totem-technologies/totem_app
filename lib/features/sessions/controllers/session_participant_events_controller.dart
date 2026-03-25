import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/session_types.dart';
import 'package:totem_app/shared/logger.dart';

class SessionParticipantEventsController {
  SessionParticipantEventsController({
    required this.currentRoom,
    required this.currentKeeperIdentity,
    required this.onLocalParticipantRemoved,
    required this.disconnect,
  });

  final CurrentRoomGetter currentRoom;
  final CurrentKeeperIdentityGetter currentKeeperIdentity;
  final VoidCallback onLocalParticipantRemoved;
  final AsyncCallback disconnect;

  bool handleDataReceived(DataReceivedEvent event) {
    if (event.topic != SessionCommunicationTopics.participantRemoved.topic) {
      return false;
    }

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
        logger.d('Participant removed event is not from the keeper, ignoring.');
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
}
