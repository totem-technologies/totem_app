import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/features/sessions/media/livekit_participant_video.dart';
import 'package:totem_core/features/sessions/media/livekit_speaker_level.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';

/// [RoomMedia] backed by the LiveKit Flutter SDK.
///
/// The session controller owns one instance for its lifetime and attaches
/// each new [Room] to it.
class LiveKitRoomMedia implements RoomMedia {
  // The room re-emits every participant's track and mute events.
  late final _media = LiveKitRoomBinding(
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

  // Speaker updates are separate from publication changes so they do not
  // rebuild video renderers and media-state subscribers on every report.
  late final _speakers = LiveKitRoomBinding(
    (listener, notify) => listener
      ..on<RoomConnectedEvent>((_) => notify())
      ..on<RoomReconnectingEvent>((_) => notify())
      ..on<RoomReconnectedEvent>((_) => notify())
      ..on<ActiveSpeakersChangedEvent>((_) => notify())
      ..on<RoomDisconnectedEvent>((_) => notify())
      ..on<ParticipantDisconnectedEvent>((_) => notify()),
  );

  void attach(Room? room) {
    _media.attach(room);
    _speakers.attach(room);
  }

  /// The server-reported amplitude for an active speaker, between 0 and 1.
  /// Participants absent from the latest active-speaker list are silent.
  double audioLevelOf(String identity) {
    final room = _speakers.room;
    if (room == null || room.connectionState != ConnectionState.connected) {
      return 0;
    }
    for (final speaker in room.activeSpeakers) {
      if (speaker.identity == identity &&
          identical(room.getParticipantByIdentity(identity), speaker)) {
        final level = speaker.audioLevel;
        return level.isFinite ? level.clamp(0.0, 1.0) : 0;
      }
    }
    return 0;
  }

  /// The current server-reported amplitude followed by changes, including
  /// silence when a speaker leaves or the room is replaced.
  Stream<double> watchAudioLevel(String identity) => Stream.multi((controller) {
    var last = audioLevelOf(identity);
    controller.add(last);
    final subscription = _speakers.changes.listen((_) {
      final next = audioLevelOf(identity);
      if (next == last) return;
      last = next;
      controller.add(next);
    });
    controller.onCancel = subscription.cancel;
  });

  Participant? _participant(String identity) =>
      _media.room?.getParticipantByIdentity(identity);

  @override
  ParticipantMediaState stateOf(String identity) {
    final participant = _participant(identity);
    if (participant == null) return ParticipantMediaState.none;

    final camera = participant.getTrackPublicationBySource(TrackSource.camera);
    // A remote track's isActive only says whether our receiving copy has
    // started, and LiveKit reports a subscription before starting it without
    // a later event. The publication's mute state follows the sender's camera.
    final isCameraOn =
        camera != null &&
        (participant is LocalParticipant
            ? isTrackLive(camera)
            : !(camera.track?.muted ?? camera.muted));
    return ParticipantMediaState(
      hasMicrophone: participant.hasAudio,
      isMicrophoneOn: isMicrophoneOn(participant),
      hasCamera: participant.hasVideo,
      isCameraOn: participant.hasVideo && isCameraOn,
    );
  }

  @override
  Stream<ParticipantMediaState> watch(String identity) {
    return Stream.multi((controller) {
      var last = stateOf(identity);
      controller.add(last);
      final subscription = _media.changes.listen((_) {
        final next = stateOf(identity);
        if (next == last) return;
        last = next;
        controller.add(next);
      });
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Widget video(ParticipantInfo participant, {bool showStats = false}) {
    return LiveKitParticipantVideo(
      participant: () => _participant(participant.identity),
      changes: _media.changes,
      showStats: showStats,
    );
  }

  @override
  Widget microphoneLevel(
    ParticipantInfo participant, {
    required Color color,
    required double iconSize,
  }) {
    return LiveKitSpeakerLevel(
      identity: participant.identity,
      participant: () => _participant(participant.identity),
      changes: _media.changes,
      audioLevel: () => audioLevelOf(participant.identity),
      audioLevelChanges: _speakers.changes,
      color: color,
      iconSize: iconSize,
    );
  }

  @override
  Widget localMicrophoneLevel({
    required Color color,
    required double iconSize,
    required int barCount,
  }) {
    return LiveKitMicrophoneLevel(
      track: _localMicrophoneTrack,
      changes: _media.changes,
      color: color,
      barCount: barCount,
      iconSize: iconSize,
    );
  }

  AudioTrack? _localMicrophoneTrack() {
    final publication = _media.room?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.microphone);
    if (publication == null || !isTrackLive(publication)) return null;
    final track = publication.track;
    return track is LocalAudioTrack ? track : null;
  }
}
