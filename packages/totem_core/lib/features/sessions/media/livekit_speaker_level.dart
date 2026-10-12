import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Level bars for a participant's microphone, driven by the audio levels the
/// LiveKit server reports, so no audio is analysed on this device. Rebuilds
/// only when the microphone state or the level changes, so a quiet room
/// costs no frames.
class LiveKitSpeakerLevel extends StatefulWidget {
  const new({
    required this.participant,
    required this.changes,
    required this.color,
    required this.iconSize,
    required this.barCount,
    super.key,
  });

  /// Looks up the participant on every change, so the bars follow them
  /// across a rejoin.
  final Participant? Function() participant;

  /// Emits whenever a participant's media or speaking level may have
  /// changed.
  final Stream<void> changes;

  final Color color;
  final double iconSize;
  final int barCount;

  @override
  State<LiveKitSpeakerLevel> createState() => _LiveKitSpeakerLevelState();
}

class _LiveKitSpeakerLevelState extends State<LiveKitSpeakerLevel> {
  StreamSubscription<void>? _subscription;
  late ({bool microphoneOn, double level}) _reading = _read();

  ({bool microphoneOn, double level}) _read() {
    final participant = widget.participant();
    final microphoneOn = participant != null && isMicrophoneOn(participant);
    final level = microphoneOn && participant.isSpeaking
        ? participant.audioLevel
        : 0.0;
    // Coarse steps keep small fluctuations from animating the bars.
    return (microphoneOn: microphoneOn, level: (level * 20).round() / 20);
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = widget.changes.listen((_) {
      final next = _read();
      if (next == _reading || !mounted) return;
      setState(() => _reading = next);
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LiveKitSpeakerLevel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) _listen();
    _reading = _read();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_reading.microphoneOn) {
      return TotemIcon(
        TotemIcons.microphoneOff,
        size: widget.iconSize,
        color: widget.color,
      );
    }
    return LevelBars.fromLevel(
      _reading.level,
      barCount: widget.barCount,
      color: widget.color,
    );
  }
}
