import 'dart:async';

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
  // Weak ownership history prevents a repeated command reclaiming room tracks.
  final Expando<bool> _claimed = Expando<bool>();
  final Set<Future<void>> _publications = {};
  final Map<LocalTrack, void Function()> _detachPreview = Map.identity();

  Future<bool> publish(
    LocalTrack? track,
    Future<bool> Function() action,
  ) async {
    final completed = Completer<void>();
    _publications.add(completed.future);
    try {
      final accepted = await action();
      if (accepted) releaseToRoom(track);
      return accepted;
    } finally {
      _publications.remove(completed.future);
      completed.complete();
    }
  }

  Future<void> waitForPublications() => Future.wait(_publications).then((_) {});

  JoinMediaReceipt retain(SessionJoinMedia? media) {
    final retained = <LocalTrack>[];
    if (media != null) {
      for (final track in [media.cameraTrack, media.microphoneTrack]) {
        if (track == null || (_claimed[track] ?? false)) continue;
        _claimed[track] = true;
        _tracks.add(track);
        if (media.onBeforeDispose case final detach?) {
          _detachPreview[track] = detach;
        }
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

  /// LiveKit owns a track after its publication succeeds.
  void releaseToRoom(LocalTrack? track) {
    if (track == null) return;
    _tracks.removeWhere((owned) => identical(owned, track));
    _detachPreview.remove(track);
  }

  Future<void> disposeTrack(LocalTrack track) => _dispose([track]);

  Future<void> disposeAll() async {
    await waitForPublications();
    await _dispose(_tracks.toList());
  }

  bool _contains(LocalTrack track) =>
      _tracks.any((owned) => identical(owned, track));

  Future<void> _dispose(Iterable<LocalTrack> candidates) async {
    final owned = <LocalTrack>[];
    final detachments = <void Function()>{};
    for (final track in candidates) {
      if (!_contains(track)) continue;
      _tracks.removeWhere((item) => identical(item, track));
      owned.add(track);
      if (_detachPreview.remove(track) case final detach?) {
        detachments.add(detach);
      }
    }
    for (final detach in detachments) {
      try {
        detach();
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to detach pre-join media before disposal',
        );
      }
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

  Future<void> dispose() => _owner._dispose(_tracks);
}
