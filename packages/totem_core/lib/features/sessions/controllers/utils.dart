import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';

List<Participant> participantsSorting({
  required List<Participant> originalParticipants,
  required SessionRoomState state,

  String? speakingNow,

  /// Whether to show the track of the participant who is currently speaking.
  bool showSpeakingNow = false,
}) {
  final speakingNowIdentity = speakingNow ?? state.speakingNow;
  final participants = originalParticipants.where((participant) {
    // Only show tracks from participants other than the speaking now
    if (participant.identity == speakingNowIdentity) {
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

  /// Walk the talking order starting after [after], wrapping around.
  String? nextInOrder({required String after}) {
    if (!talkingOrder.contains(after)) return null;

    final start = talkingOrder.indexOf(after) + 1;
    final rotated = [
      ...talkingOrder.sublist(start),
      ...talkingOrder.sublist(0, start),
    ];

    return rotated.firstOrNull;
  }

  String? get nextParticipantForcePassIdentity {
    if (nextSpeaker == null) return null;
    switch (turnState) {
      case TurnState.idle:
        return null;
      case TurnState.speaking:
        return nextSpeaker;
      case TurnState.passing:
        return nextInOrder(after: nextSpeaker!);
    }
    return null;
  }
}
