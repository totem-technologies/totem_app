import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

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
    final participantsMap = {for (final p in participants) p.identity: p};

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

    final nextSpeaker = state.roomState.nextSpeaker;
    if (nextSpeaker != null) {
      final nextIndex = sortedParticipants.indexWhere(
        (p) => p.identity == nextSpeaker,
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
  /// Walk the talking order starting after [after], wrapping around.
  String? nextInOrder({
    required String after,
    required Iterable<Participant> participants,
  }) {
    if (!talkingOrder.contains(after)) return null;

    final onlineIds = participants.map((p) => p.identity).toSet();

    final start = talkingOrder.indexOf(after) + 1;
    final rotated = [
      ...talkingOrder.sublist(start),
      ...talkingOrder.sublist(0, start),
    ];

    return rotated.where(onlineIds.contains).firstOrNull;
  }

  /// The identity of the participant to be forced pass to.
  ///
  /// For example, in the list [Bob, Foo, Boo, Fob], if Bob is speaking and the Keeper wants to
  /// force pass them, they would pass to Foo. If Foo is passing, the keeper would pass to Boo.
  String? nextParticipantForcePassIdentity({
    required Iterable<Participant> participants,
  }) {
    if (nextSpeaker == null) return null;
    switch (turnState) {
      case TurnState.idle:
        return null;
      case TurnState.speaking:
        return nextSpeaker;
      case TurnState.passing:
        return nextInOrder(after: nextSpeaker!, participants: participants);
    }
    return null;
  }
}
