import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/features/sessions/media/livekit_participant_video.dart';
import 'package:totem_core/features/sessions/media/livekit_speaker_level.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/media/speech_level.dart';

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
      ..on<ParticipantDisconnectedEvent>((event) {
        _meters.remove(event.participant.identity);
        notify();
      })
      ..on<TrackPublishedEvent>((_) => notify())
      ..on<TrackUnpublishedEvent>((_) => notify())
      ..on<TrackSubscribedEvent>((_) => notify())
      ..on<TrackUnsubscribedEvent>((_) => notify())
      ..on<LocalTrackPublishedEvent>((_) => notify())
      ..on<LocalTrackUnpublishedEvent>((_) => notify())
      ..on<TrackMutedEvent>((_) => notify())
      ..on<TrackUnmutedEvent>((_) => notify()),
  );

  // Speaker updates arrive several times a second while anyone talks, so
  // they get their own binding and only wake the level bars.
  final _speakers = LiveKitRoomBinding(
    (listener, notify) =>
        listener.on<ActiveSpeakersChangedEvent>((_) => notify()),
  );

  late final Stream<void> _levelChanges = Stream<void>.multi((controller) {
    final subscriptions = [
      _media.changes.listen(controller.addSync),
      _speakers.changes.listen(controller.addSync),
    ];
    controller.onCancel = () =>
        Future.wait([for (final s in subscriptions) s.cancel()]);
  }, isBroadcast: true);

  /// Each participant's level scaling, kept while they are in the room.
  final _meters = <String, SpeechLevelMeter>{};

  void attach(Room? room) {
    if (!identical(room, _media.room)) _meters.clear();
    _media.attach(room);
    _speakers.attach(room);
  }

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
      participant: () => _participant(participant.identity),
      changes: _levelChanges,
      meter: _meters.putIfAbsent(participant.identity, SpeechLevelMeter.new),
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
