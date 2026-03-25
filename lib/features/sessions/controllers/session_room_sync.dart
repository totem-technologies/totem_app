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

  SessionRoomState reduceState(SessionRoomState current, _SessionEvent event) {
    switch (event) {
      case _ConnectionChanged():
        return SessionRoomState(
          connection: current.connection.copyWith(
            state: event.connectionState,
            phase: event.phase,
            clearError: event.connectionState == RoomConnectionState.connected,
          ),
          participants: event.connectionState == RoomConnectionState.connected
              ? current.participants.copyWith(removed: false)
              : current.participants,
          chat: current.chat,
          turn: current.turn,
        );
      case _RoomStateChanged():
        final isEnded = event.roomState.status == RoomStatus.ended;
        return SessionRoomState(
          connection: current.connection.copyWith(
            phase: isEnded ? SessionPhase.ended : null,
          ),
          participants: current.participants,
          chat: current.chat,
          turn: current.turn.copyWith(roomState: event.roomState),
        );
      case _ParticipantsChanged():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(
            participants: event.participants,
          ),
          chat: current.chat,
          turn: current.turn,
        );
      case _KeeperDisconnectedChanged():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(
            hasKeeperDisconnected: event.hasKeeperDisconnected,
          ),
          chat: current.chat,
          turn: current.turn,
        );
      case _ParticipantRemoved():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants.copyWith(removed: true),
          chat: current.chat,
          turn: current.turn,
        );
      case _SpeakerphoneChanged():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants,
          chat: current.chat,
          turn: current.turn.copyWith(
            isSpeakerphoneEnabled: event.isSpeakerphoneEnabled,
          ),
        );
      case _DisconnectReasonChanged():
        return current;
      case _SessionErrorChanged():
        return SessionRoomState(
          connection: current.connection.copyWith(
            error: event.error,
            state: event.error is RoomLiveKitError
                ? RoomConnectionState.error
                : current.connection.state,
            phase: event.error is RoomLiveKitError ? SessionPhase.error : null,
          ),
          participants: current.participants,
          chat: current.chat,
          turn: current.turn,
        );
      case _LiveKitErrorChanged():
        return current;
      case _ChatMessageAdded():
        return SessionRoomState(
          connection: current.connection,
          participants: current.participants,
          chat: current.chat.copyWith(
            messages: [...current.chat.messages, event.message],
          ),
          turn: current.turn,
        );
    }
  }
}
