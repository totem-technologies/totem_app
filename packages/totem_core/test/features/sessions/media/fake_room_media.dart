import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';

/// In-memory [RoomMedia]. Its views are placeholder widgets tests can find
/// by type.
class FakeRoomMedia implements RoomMedia {
  final _states = <String, ParticipantMediaState>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Updates a participant's media, like a remote mute or camera change.
  void setMediaState(String identity, ParticipantMediaState state) {
    _states[identity] = state;
    _changes.add(null);
  }

  ParticipantMediaState _stateOf(String identity) =>
      _states[identity] ?? ParticipantMediaState.none;

  @override
  Stream<ParticipantMediaState> watch(String identity) {
    return Stream.multi((controller) {
      controller.add(_stateOf(identity));
      final subscription = _changes.stream.listen(
        (_) => controller.add(_stateOf(identity)),
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Widget video(ParticipantInfo participant, {bool showStats = false}) =>
      FakeVideoView(participant: participant);

  @override
  Widget microphoneLevel(
    ParticipantInfo participant, {
    required Color color,
    required double iconSize,
    int barCount = 3,
  }) => FakeMicrophoneLevel(participant: participant, barCount: barCount);
}

class FakeVideoView extends StatelessWidget {
  const FakeVideoView({required this.participant, super.key});

  final ParticipantInfo participant;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class FakeMicrophoneLevel extends StatelessWidget {
  const FakeMicrophoneLevel({
    required this.participant,
    required this.barCount,
    super.key,
  });

  final ParticipantInfo participant;
  final int barCount;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
