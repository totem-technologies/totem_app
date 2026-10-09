import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';

extension LiveKitParticipantInfo on Participant {
  ParticipantInfo toInfo() => ParticipantInfo(
    sid: sid,
    identity: identity,
    name: name,
    isLocal: this is LocalParticipant,
  );
}

/// Whether [publication] carries live media. Before a remote track is
/// subscribed, the publication's own mute state stands in for the track's.
bool isTrackLive(TrackPublication publication) {
  final track = publication.track;
  return (track?.isActive ?? true) && !(track?.muted ?? publication.muted);
}

/// Follows whichever [Room] is attached and reports changes from it.
///
/// The session controller attaches each new room, so subscribers to
/// [changes] survive reconnects. [register] adds the room events that should
/// report a change; handlers call the `notify` callback it receives.
class LiveKitRoomBinding {
  LiveKitRoomBinding(this.register);

  final void Function(
    EventsListener<RoomEvent> listener,
    void Function() notify,
  )
  register;

  final _changes = StreamController<void>.broadcast(sync: true);
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  Room? get room => _room;

  /// Emits when the attached room changes or one of its registered events
  /// fires.
  Stream<void> get changes => _changes.stream;

  void attach(Room? room) {
    if (identical(room, _room)) return;
    unawaited(_listener?.dispose());
    _listener = null;
    _room = room;
    if (room != null) {
      final listener = room.createListener();
      // Disposing the previous listener is asynchronous, so events from a
      // detached room can still arrive. Only the attached room may notify.
      register(listener, () {
        if (identical(room, _room)) _changes.add(null);
      });
      _listener = listener;
    }
    _changes.add(null);
  }
}
