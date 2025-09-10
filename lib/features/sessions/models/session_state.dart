import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

enum SessionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

@immutable
class SessionState {
  const SessionState({
    this.status = SessionStatus.disconnected,
    this.roomName,
    this.room,
    this.participantTracks,
    this.error,
  });
  factory SessionState.disconnected() => const SessionState();

  final SessionStatus status;
  final String? roomName;
  final Room? room;
  final List<ParticipantTrack>? participantTracks;
  final String? error;

  SessionState copyWith({
    SessionStatus? status,
    String? roomName,
    Room? room,
    List<ParticipantTrack>? participantTracks,
    String? error,
  }) {
    return SessionState(
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      room: room ?? this.room,
      participantTracks: participantTracks ?? this.participantTracks,
      error: error ?? this.error,
    );
  }
}

class ParticipantTrack {
  const ParticipantTrack({required this.participant, required this.videoTrack});

  final Participant participant;
  final Track videoTrack;
}
