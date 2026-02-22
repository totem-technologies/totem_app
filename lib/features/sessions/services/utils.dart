import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';

List<Participant> participantsSorting({
  required List<Participant> originalParticiapnts,
  required SessionRoomState state,

  String? speakingNow,

  /// Whether to show the track of the participant who is currently speaking.
  bool showSpeakingNow = false,
}) {
  final speakingNowIndentity = speakingNow ?? state.speakingNow;
  final participants = originalParticiapnts.where((participant) {
    // Only show tracks from participants other than the speaking now
    if (participant.identity == speakingNowIndentity) {
      return showSpeakingNow;
    }
    return true;
  }).toList();

  if (state.roomState.talkingOrder.isNotEmpty) {
    final participantsMap = {
      for (final p in participants) p.identity: p,
    };

    final speakingOrderSet = state.roomState.talkingOrder.toSet();
    final sortedParticipants = <Participant>[];

    for (final identity in state.roomState.talkingOrder) {
      final participant = participantsMap[identity];
      if (participant != null) {
        sortedParticipants.add(participant);
      }
    }

    for (final participant in participants) {
      final identity = participant.identity;
      if (!speakingOrderSet.contains(identity)) {
        sortedParticipants.add(participant);
      }
    }

    // Rotate the list so the next participant is first (circular order)
    final nextIdentity = state.roomState.nextParticipantIdentity;
    if (nextIdentity != null) {
      final nextIndex = sortedParticipants.indexWhere(
        (p) => p.identity == nextIdentity,
      );
      if (nextIndex > 0) {
        final rotated = [
          ...sortedParticipants.sublist(nextIndex),
          ...sortedParticipants.sublist(0, nextIndex),
        ];
        return rotated;
      }
    }

    return sortedParticipants;
  }

  return participants;
}

extension SessionStateExtension on RoomState {
  String? get nextParticipantIdentity {
    if (talkingOrder.isEmpty) return null;
    if (currentSpeaker == null) return talkingOrder.first;

    final currentIndex = talkingOrder.indexOf(currentSpeaker!);
    if (currentIndex == -1) return null;
    if (currentIndex == talkingOrder.length - 1) return talkingOrder.first;
    return talkingOrder[currentIndex + 1];
  }
}
