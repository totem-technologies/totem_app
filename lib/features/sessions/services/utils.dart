import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart';
// We need the defaultSorting function from livekit_components
// ignore: implementation_imports
import 'package:livekit_components/src/ui/layout/sorting.dart'
    show defaultSorting;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/session_state.dart';

List<TrackWidget> tracksSorting({
  required BuildContext context,
  required List<TrackWidget> originalTracks,
  required SessionState sessionState,
  required EventDetailSchema event,

  /// Whether to show the track of the participant who is currently speaking.
  bool showSpeakingNow = false,
}) {
  final roomCtx = RoomContext.of(context)!;
  final speakingNow = roomCtx.participants.firstWhere(
    (participant) {
      if (sessionState.speakingNow != null) {
        return participant.identity == sessionState.speakingNow;
      } else {
        // If no one is speaking right now, show the keeper's video
        return participant.identity == event.space.author.slug!;
      }
    },
    orElse: () => roomCtx.localParticipant!,
  );
  final tracks = originalTracks.where((track) {
    // Only show tracks from participants other than the speaking
    // now
    if (track.trackIdentifier.participant.identity == speakingNow.identity) {
      return showSpeakingNow;
    }
    return true;
  });

  if (sessionState.speakingOrder.isNotEmpty) {
    final sortedTracks = <TrackWidget>[];
    final tracksMap = {
      for (final t in tracks) t.trackIdentifier.participant.identity: t,
    };

    for (final identity in sessionState.speakingOrder) {
      if (tracksMap.containsKey(identity)) {
        sortedTracks.add(tracksMap[identity]!);
      }
    }
    for (final MapEntry(:key, :value) in tracksMap.entries) {
      if (!sessionState.speakingOrder.contains(key)) {
        sortedTracks.add(value);
      }
    }

    return sortedTracks;
  }

  return defaultSorting(tracks.toList());
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
