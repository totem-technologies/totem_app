import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';

/// Owns pre-join tracks between their UI transfer and LiveKit accepting them.
///
/// A receipt scopes cleanup to tracks newly supplied by one join call. This is
/// important for a no-op join while another join is already in flight: the new
/// tracks are disposed without touching the in-flight tracks.
class JoinMediaOwner {
  final List<LocalTrack> _tracks = [];

  JoinMediaReceipt retain(SessionJoinMedia? media) {
    final retained = <LocalTrack>[];
    if (media != null) {
      for (final track in [media.cameraTrack, media.microphoneTrack]) {
        if (track == null || _contains(track)) continue;
        _tracks.add(track);
        retained.add(track);
      }
    }
    return JoinMediaReceipt._(this, retained);
  }

  T? track<T extends LocalTrack>() {
    for (final track in _tracks.reversed) {
      if (track is T) return track;
    }
    return null;
  }

  /// LiveKit owns a track after Room.connect succeeds.
  void releaseToRoom(LocalTrack? track) {
    if (track == null) return;
    _tracks.removeWhere((owned) => identical(owned, track));
  }

  Future<void> disposeAll() => _dispose(_tracks.toList());

  bool _contains(LocalTrack track) =>
      _tracks.any((owned) => identical(owned, track));

  Future<void> _dispose(Iterable<LocalTrack> candidates) async {
    final owned = <LocalTrack>[];
    for (final track in candidates) {
      if (!_contains(track)) continue;
      _tracks.removeWhere((item) => identical(item, track));
      owned.add(track);
    }
    await Future.wait(owned.map(_disposeTrack));
  }

  Future<void> _disposeTrack(LocalTrack track) async {
    try {
      await track.stop();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to stop owned pre-join media',
      );
    }
    try {
      await track.dispose();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to dispose owned pre-join media',
      );
    }
  }
}

class JoinMediaReceipt {
  JoinMediaReceipt._(this._owner, this._tracks);

  final JoinMediaOwner _owner;
  final List<LocalTrack> _tracks;

  bool get hasOwnedTracks => _tracks.any(_owner._contains);

  Future<void> dispose() => _owner._dispose(_tracks);
}
