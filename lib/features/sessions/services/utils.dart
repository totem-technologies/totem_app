import 'package:livekit_components/livekit_components.dart';
// We need the defaultSorting function from livekit_components
// ignore: implementation_imports
import 'package:livekit_components/src/ui/layout/sorting.dart'
    show defaultSorting;
import 'package:totem_app/api/export.dart';

List<TrackWidget> tracksSorting({
  required List<TrackWidget> originalTracks,
  required SessionState sessionState,
  required String? speakingNow,

  /// Whether to show the track of the participant who is currently speaking.
  bool showSpeakingNow = false,
}) {
  final tracks = originalTracks.where((track) {
    // Only show tracks from participants other than the speaking
    // now
    if (track.trackIdentifier.participant.identity == speakingNow) {
      return showSpeakingNow;
    }
    return true;
  }).toList();

  if (sessionState.speakingOrder.isNotEmpty) {
    final tracksMap = {
      for (final t in tracks) t.trackIdentifier.participant.identity: t,
    };

    final speakingOrderSet = sessionState.speakingOrder.toSet();
    final sortedTracks = <TrackWidget>[];

    for (final identity in sessionState.speakingOrder) {
      final track = tracksMap[identity];
      if (track != null) {
        sortedTracks.add(track);
      }
    }

    for (final track in tracks) {
      final identity = track.trackIdentifier.participant.identity;
      if (!speakingOrderSet.contains(identity)) {
        sortedTracks.add(track);
      }
    }

    return sortedTracks;
  }

  return defaultSorting(tracks);
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
