import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';
import 'package:totem_app/features/sessions/services/livekit_service.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      return SessionController(ref);
    });

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(SessionState.disconnected());

  final Ref _ref;
  late final LiveKitService _livekitService = _ref.read(livekitServiceProvider);
  void Function()? _roomSubscription;

  bool get isInSession => state.status == SessionStatus.connected;

  Future<void> joinSession(
    String roomName,
    String token, {
    bool cameraEnabled = true,
    bool micEnabled = true,
  }) async {
    if (isInSession) return;

    state = state.copyWith(
      status: SessionStatus.connecting,
      roomName: roomName,
    );

    try {
      await _livekitService.connect(
        roomName,
        token,
      );
      _roomSubscription = _livekitService.listener?.listen(_onRoomEvent);
      _updateParticipantTracks();
      state = state.copyWith(
        status: SessionStatus.connected,
        room: _livekitService.room,
      );
    } catch (e) {
      state = state.copyWith(
        status: SessionStatus.error,
        error: 'Failed to connect to room.',
      );
    }
  }

  Future<void> leaveSession() async {
    if (!isInSession) return;
    _roomSubscription?.call();
    _livekitService.disconnect();
    state = SessionState.disconnected();
  }

  void _onRoomEvent(RoomEvent event) {
    if (event is RoomDisconnectedEvent) {
      leaveSession();
    } else if (event is ParticipantEvent) {
      _updateParticipantTracks();
    }
  }

  void _updateParticipantTracks() {
    if (_livekitService.room == null) return;
    final tracks = <ParticipantTrack>[];
    for (final participant in <Participant>[
      ?_livekitService.room!.localParticipant,
      ..._livekitService.room!.remoteParticipants.values,
    ]) {
      final track = participant.videoTrackPublications.firstOrNull?.track;
      if (track != null) {
        tracks.add(
          ParticipantTrack(participant: participant, videoTrack: track),
        );
      }
    }
    state = state.copyWith(participantTracks: tracks);
  }
}
