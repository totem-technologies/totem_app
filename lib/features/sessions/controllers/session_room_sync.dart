part of 'session_controller.dart';

class SessionRoomMetadataResult {
  const SessionRoomMetadataResult({
    required this.roomState,
    required this.lastMetadata,
  });

  final RoomState? roomState;
  final String? lastMetadata;
}

class SessionRoomSync {
  const SessionRoomSync();

  List<Participant> sortedParticipants({
    required Room? room,
    required SessionRoomState state,
  }) {
    final participants = <Participant>[
      if (room != null) ...[
        ...room.remoteParticipants.values,
        if (room.localParticipant != null) room.localParticipant!,
      ],
    ];

    return participantsSorting(
      originalParticipants: participants,
      state: state,
      showSpeakingNow: true,
    );
  }

  SessionRoomMetadataResult resolveMetadataState({
    required String? metadata,
    required String? lastMetadata,
  }) {
    if (metadata == null || metadata.isEmpty) {
      return SessionRoomMetadataResult(
        roomState: null,
        lastMetadata: lastMetadata,
      );
    }

    try {
      if (lastMetadata == null) {
        return SessionRoomMetadataResult(
          roomState: RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          ),
          lastMetadata: metadata,
        );
      }

      if (metadata != lastMetadata) {
        return SessionRoomMetadataResult(
          roomState: RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          ),
          lastMetadata: metadata,
        );
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error decoding session metadata',
      );
    }

    return SessionRoomMetadataResult(
      roomState: null,
      lastMetadata: lastMetadata,
    );
  }
}
