import 'dart:async';
import 'dart:math' as math;

import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/features/sessions/media/livekit_selector.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';

import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// A participant microphone indicator driven by room-reported audio levels.
class LiveKitSpeakerLevel extends StatelessWidget {
  const LiveKitSpeakerLevel({
    required this.participant,
    required this.changes,
    required this.audioLevel,
    required this.audioLevelChanges,
    required this.color,
    required this.iconSize,
    this.identity = '',
    super.key,
  });

  /// Looks up the participant on every change, so the bars follow them
  /// across a rejoin.
  final Participant? Function() participant;

  /// Emits whenever the participant's microphone publication or track may
  /// have changed.
  final Stream<void> changes;

  /// Latest server-reported amplitude and notifications when it may change.
  final double Function() audioLevel;
  final Stream<void> audioLevelChanges;

  /// Stable participant identity used to distinguish remote waveforms.
  final String identity;
  final Color color;
  final double iconSize;

  TrackPublication<Track>? _publication([Participant? participant]) =>
      (participant ?? this.participant())?.getTrackPublicationBySource(
        TrackSource.microphone,
      );

  bool _microphoneOn() {
    final participant = this.participant();
    if (participant == null) return false;
    return isMicrophoneOn(participant) &&
        !(_publication(participant)?.muted ?? false);
  }

  AudioTrack? _track() {
    final track = _publication()?.track;
    return track is AudioTrack ? track : null;
  }

  @override
  Widget build(BuildContext context) => LiveKitSelector(
    changes: changes,
    read: () => (on: _microphoneOn(), local: participant() is LocalParticipant),
    builder: (context, state) {
      if (!state.on) {
        return TotemIcon(
          TotemIcons.microphoneOff,
          size: iconSize,
          color: color,
        );
      }
      if (state.local) {
        return LiveKitMicrophoneLevel(
          track: _track,
          changes: changes,
          color: color,
          barCount: 5,
          microphoneOn: _microphoneOn,
          iconSize: iconSize,
        );
      }
      return _RemoteWaveform(
        identity: identity,
        audioLevel: audioLevel,
        changes: audioLevelChanges,
        color: color,
      );
    },
  );
}

class _RemoteWaveform extends StatefulWidget {
  const _RemoteWaveform({
    required this.identity,
    required this.audioLevel,
    required this.changes,
    required this.color,
  });

  final String identity;
  final double Function() audioLevel;
  final Stream<void> changes;
  final Color color;

  @override
  State<_RemoteWaveform> createState() => _RemoteWaveformState();
}

class _RemoteWaveformState extends State<_RemoteWaveform> {
  final _levels = ValueNotifier<List<double>>(const [0, 0, 0, 0, 0]);
  late StreamSubscription<void> _subscription;

  double? _lastLevel;
  late double _phase;

  void _seed() {
    var hash = 2166136261;
    for (final unit in widget.identity.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    _phase = hash / 0x7fffffff * 2 * math.pi;

    _lastLevel = null;
  }

  void _update() {
    final input = widget.audioLevel();
    final amplitude = input.isFinite ? input.clamp(0.0, 1.0) : 0.0;
    // Gate below -50 dBFS and compress the remaining server amplitudes.
    const noiseGate = 0.0031622776601683794;
    final level = math.sqrt(
      ((amplitude - noiseGate) / (1 - noiseGate)).clamp(0.0, 1.0),
    );
    final previous = _lastLevel;
    if (level == previous) return;
    _lastLevel = level;
    if (level == 0) {
      if (_levels.value.any((value) => value != 0)) {
        _levels.value = const [0, 0, 0, 0, 0];
      }
      return;
    }
    // Advance the identity-specific contour only when the sound changes.
    _phase =
        (_phase + (level - (previous ?? level)).abs() * 1.5) % (2 * math.pi);
    const weights = [0.52, 0.86, 0.95, 0.86, 0.52];
    _levels.value = List<double>.generate(
      5,
      (i) => level * weights[i] * (0.85 + 0.15 * math.sin(_phase + i * 1.1)),
      growable: false,
    );
  }

  @override
  void initState() {
    super.initState();
    _seed();
    _update();
    _subscription = widget.changes.listen((_) => _update());
  }

  @override
  void didUpdateWidget(_RemoteWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _seed();
      _update();
    }
    if (oldWidget.changes != widget.changes) {
      _subscription.cancel();
      _subscription = widget.changes.listen((_) => _update());
      if (oldWidget.identity == widget.identity) _update();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _levels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LevelBars(
    levels: _levels,
    color: widget.color,
    animateInitial: true,
    releaseDuration: const Duration(milliseconds: 200),
  );
}
