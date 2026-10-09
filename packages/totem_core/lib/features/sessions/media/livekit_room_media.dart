import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/features/sessions/media/livekit_participant_video.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';

/// [RoomMedia] backed by the LiveKit Flutter SDK.
///
/// The session controller owns one instance for its lifetime and attaches
/// each new [Room] to it.
class LiveKitRoomMedia implements RoomMedia {
  // The room re-emits every participant's track and mute events.
  final _binding = LiveKitRoomBinding(
    (listener, notify) => listener
      ..on<RoomConnectedEvent>((_) => notify())
      ..on<RoomDisconnectedEvent>((_) => notify())
      ..on<ParticipantConnectedEvent>((_) => notify())
      ..on<ParticipantDisconnectedEvent>((_) => notify())
      ..on<TrackPublishedEvent>((_) => notify())
      ..on<TrackUnpublishedEvent>((_) => notify())
      ..on<TrackSubscribedEvent>((_) => notify())
      ..on<TrackUnsubscribedEvent>((_) => notify())
      ..on<LocalTrackPublishedEvent>((_) => notify())
      ..on<LocalTrackUnpublishedEvent>((_) => notify())
      ..on<TrackMutedEvent>((_) => notify())
      ..on<TrackUnmutedEvent>((_) => notify()),
  );

  void attach(Room? room) => _binding.attach(room);

  Participant? _participant(String identity) =>
      _binding.room?.getParticipantByIdentity(identity);

  ParticipantMediaState _stateOf(String identity) {
    final participant = _participant(identity);
    if (participant == null) return ParticipantMediaState.none;

    final camera = participant.videoTrackPublications.firstOrNull;
    final isCameraOn = camera != null && isTrackLive(camera);
    return ParticipantMediaState(
      hasMicrophone: participant.hasAudio,
      isMicrophoneOn: participant.hasAudio && !participant.isMuted,
      hasCamera: participant.hasVideo,
      isCameraOn: participant.hasVideo && isCameraOn,
    );
  }

  @override
  Stream<ParticipantMediaState> watch(String identity) {
    return Stream.multi((controller) {
      var last = _stateOf(identity);
      controller.add(last);
      final subscription = _binding.changes.listen((_) {
        final next = _stateOf(identity);
        if (next == last) return;
        last = next;
        controller.add(next);
      });
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Widget video(ParticipantInfo participant, {bool showStats = false}) {
    final media = _participant(participant.identity);
    if (media == null) return const SizedBox.shrink();
    return LiveKitParticipantVideo(participant: media, showStats: showStats);
  }

  @override
  Widget microphoneLevel(
    ParticipantInfo participant, {
    required Color color,
    required double iconSize,
    int barCount = 3,
  }) {
    return LiveKitMicrophoneLevel(
      participant: _participant(participant.identity),
      foregroundColor: color,
      barCount: barCount,
      iconSize: iconSize,
    );
  }
}
