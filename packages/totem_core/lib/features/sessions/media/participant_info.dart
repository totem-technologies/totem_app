import 'package:flutter/foundation.dart';

/// A room participant as session logic and widgets see it, independent of the
/// media SDK. Media state (tracks, mute, audio levels) is not part of it.
@immutable
class ParticipantInfo {
  const ParticipantInfo({
    required this.sid,
    required this.identity,
    required this.name,
    this.isLocal = false,
  });

  /// Server-assigned id for this connection. Changes when the participant
  /// rejoins, unlike [identity].
  final String sid;

  /// Stable id across rejoins; the user's slug.
  final String identity;
  final String name;
  final bool isLocal;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantInfo &&
        other.sid == sid &&
        other.identity == identity &&
        other.name == name &&
        other.isLocal == isLocal;
  }

  @override
  int get hashCode => Object.hash(sid, identity, name, isLocal);

  @override
  String toString() => 'ParticipantInfo($identity, sid: $sid)';
}
