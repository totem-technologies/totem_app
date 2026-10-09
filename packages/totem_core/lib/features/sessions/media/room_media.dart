import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';

/// Whether a participant publishes a microphone and camera, and whether each
/// is on.
@immutable
class ParticipantMediaState {
  const ParticipantMediaState({
    this.hasMicrophone = false,
    this.isMicrophoneOn = false,
    this.hasCamera = false,
    this.isCameraOn = false,
  });

  static const none = ParticipantMediaState();

  final bool hasMicrophone;
  final bool isMicrophoneOn;
  final bool hasCamera;
  final bool isCameraOn;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantMediaState &&
        other.hasMicrophone == hasMicrophone &&
        other.isMicrophoneOn == isMicrophoneOn &&
        other.hasCamera == hasCamera &&
        other.isCameraOn == isCameraOn;
  }

  @override
  int get hashCode =>
      Object.hash(hasMicrophone, isMicrophoneOn, hasCamera, isCameraOn);
}

/// Media of every participant in a room, local and remote.
///
/// Rendering is part of the interface because each media SDK delivers video
/// and audio differently, such as textures, platform views or DOM elements.
/// Callers own everything drawn around the media: avatars, names and badges.
abstract interface class RoomMedia {
  /// The participant's current media state, then every change to it.
  Stream<ParticipantMediaState> watch(String identity);

  /// The participant's camera video, sized to fill its parent. Empty until a
  /// camera track is available, so a placeholder underneath stays visible.
  /// Implementations may keep a muted camera's renderer mounted to avoid a
  /// flash on unmute; callers that need to hide it use [watch].
  /// [showStats] adds a staff-only overlay with stream statistics.
  Widget video(ParticipantInfo participant, {bool showStats = false});

  /// Live audio level bars for the participant's microphone, or a
  /// microphone-off icon while it is muted or missing.
  Widget microphoneLevel(
    ParticipantInfo participant, {
    required Color color,
    required double iconSize,
    int barCount = 3,
  });
}
