import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';

List<Participant> participantsSorting({
  required List<Participant> originalParticiapnts,
  required SessionRoomState state,

  /// Whether to show the track of the participant who is currently speaking.
  bool showSpeakingNow = false,
}) {
  final participants = originalParticiapnts.where((participant) {
    // Only show tracks from participants other than the speaking
    // now
    if (participant.identity == state.speakingNow) {
      return showSpeakingNow;
    }
    return true;
  }).toList();

  if (state.sessionState.speakingOrder.isNotEmpty) {
    final participantsMap = {
      for (final p in participants) p.identity: p,
    };

    final speakingOrderSet = state.sessionState.speakingOrder.toSet();
    final sortedParticipants = <Participant>[];

    for (final identity in state.sessionState.speakingOrder) {
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

    return sortedParticipants;
  }

  return participants;
}

extension SessionStateExtension on SessionState {
  String? get nextParticipantIdentity {
    if (speakingOrder.isEmpty) return null;
    if (speakingNow == null) return speakingOrder.first;

    final currentIndex = speakingOrder.indexOf(speakingNow!);
    if (currentIndex == -1) return null;
    if (currentIndex == speakingOrder.length - 1) return speakingOrder.first;
    return speakingOrder[currentIndex + 1];
  }
}
