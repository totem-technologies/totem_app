// file copied from livekit_components package and modified
// This is an optimized version of the audio visualizer that does not rely heavily on
// native FFT data and instead simulates the visualizer based on the participant's
// speaking state.
//
// We are experimenting this approach as it is more performant, hoping it reduces
// CPU usage and improves battery life, especially on lower-end devices. The visualizer
// is less accurate as it does not reflect the actual audio frequencies, but it still
// provides a nice visual indication of when a participant is speaking.
//
// This will likely not be used because, in our implementation, usually one person is
// speaking at a time, and the performance improvement is not significant enough to
// justify the loss of accuracy. However, it can be a good fallback option for devices
// that struggle with the native FFT-based visualizer.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:totem_app/core/errors/error_handler.dart';

enum VisualizerState { thinking, listening, active }

@immutable
class AudioVisualizerWidgetOptions {
  const AudioVisualizerWidgetOptions({
    this.barCount = 7,
    this.centeredBands = true,
    this.width = 12,
    this.minHeight = 12,
    this.maxHeight = 100,
    this.durationInMilliseconds = 500,
    this.color,
    this.spacing = 5,
    this.cornerRadius = 9999,
    this.barMinOpacity = 0.2,
  });
  final int barCount;
  final bool centeredBands;
  final double width;
  final double minHeight;
  final double maxHeight;
  final int durationInMilliseconds;
  final Color? color;
  final double spacing;
  final double cornerRadius;
  final double barMinOpacity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioVisualizerWidgetOptions &&
        other.barCount == barCount &&
        other.centeredBands == centeredBands &&
        other.width == width &&
        other.minHeight == minHeight &&
        other.maxHeight == maxHeight &&
        other.durationInMilliseconds == durationInMilliseconds &&
        other.color == color &&
        other.spacing == spacing &&
        other.cornerRadius == cornerRadius &&
        other.barMinOpacity == barMinOpacity;
  }

  @override
  int get hashCode {
    return Object.hash(
      barCount,
      centeredBands,
      width,
      minHeight,
      maxHeight,
      durationInMilliseconds,
      color,
      spacing,
      cornerRadius,
      barMinOpacity,
    );
  }
}

extension _ComputeExt on AudioVisualizerWidgetOptions {
  Color computeColor(BuildContext ctx) =>
      color ?? Theme.of(ctx).colorScheme.primary;
}

class SoundWaveformWidget extends StatefulWidget {
  const SoundWaveformWidget({
    super.key,
    this.participant,
    this.audioTrack,
    this.options = const AudioVisualizerWidgetOptions(),
  });
  final sdk.Participant? participant;
  final sdk.AudioTrack? audioTrack;
  final AudioVisualizerWidgetOptions options;

  @override
  State<SoundWaveformWidget> createState() => _SoundWaveformWidgetState();
}

class _SoundWaveformWidgetState extends State<SoundWaveformWidget>
    with SingleTickerProviderStateMixin {
  final math.Random _random = math.Random();
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  List<double> samples = <double>[];
  List<double> _backgroundSamples = <double>[];
  Timer? _uiThrottleTimer;

  sdk.EventsListener<sdk.ParticipantEvent>? _participantListener;

  // Local track analyzer (only used for local user)
  sdk.AudioVisualizer? _visualizer;
  sdk.EventsListener<sdk.AudioVisualizerEvent>? _visualizerListener;

  // Cached bar items
  List<BarsViewItem>? _cachedBarItems;
  VisualizerState? _lastState;
  List<double>? _lastSamples;
  double _lastSimulatedLevel = 0;

  bool get isLocalParticipant =>
      widget.participant is sdk.LocalParticipant || widget.audioTrack != null;

  Future<void> _detachListeners() async {
    if (_visualizer != null) {
      try {
        await _visualizer?.stop();
        await _visualizer?.dispose();
      } catch (_) {}
      _visualizer = null;
    }

    try {
      await _visualizerListener?.dispose();
    } catch (_) {}
    _visualizerListener = null;

    try {
      await _participantListener?.dispose();
    } catch (_) {}
    _participantListener = null;
  }

  @override
  void initState() {
    super.initState();

    samples = List.filled(widget.options.barCount, 0, growable: false);
    _backgroundSamples = List.filled(
      widget.options.barCount,
      0,
      growable: false,
    );

    _controller = AnimationController(
      duration: Duration(milliseconds: widget.options.durationInMilliseconds),
      vsync: this,
    );

    _pulseAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // UNIFIED UI LOOP: Handles both Local (FFT) and Remote (Simulated)
    _uiThrottleTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      _throttleCallback();
    });

    _attachListeners();
  }

  Future<void> _attachListeners() async {
    try {
      if (widget.participant != null) {
        _participantListener = widget.participant!.createListener();

        _participantListener?.on<sdk.TrackMutedEvent>((e) {
          if (!mounted) return;
          _lastSimulatedLevel = 0.0;
          setState(() {
            samples = List.filled(widget.options.barCount, 0);
          });
        });
      }

      if (isLocalParticipant) {
        _visualizer = sdk.createVisualizer(
          widget.audioTrack!,
          options: sdk.AudioVisualizerOptions(
            barCount: widget.options.barCount,
            centeredBands: widget.options.centeredBands,
          ),
        );

        _visualizerListener = _visualizer?.createListener();
        _visualizerListener?.on<sdk.AudioVisualizerEvent>((element) {
          if (!mounted) return;
          final events = element.event;

          for (
            var i = 0;
            i < _backgroundSamples.length && i < events.length;
            i++
          ) {
            final v = events[i];
            _backgroundSamples[i] = (v is num) ? v.toDouble() : 0.0;
          }
        });

        await _visualizer!.start();
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to attach audio visualizer listeners',
      );
    }
  }

  void _throttleCallback() {
    if (!mounted) return;

    if (isLocalParticipant) {
      // LOCAL PARTICIPANT (FFT sync via background samples)
      bool hasChanges = false;
      if (_backgroundSamples.length == samples.length) {
        for (var i = 0; i < samples.length; i++) {
          if ((samples[i] - _backgroundSamples[i]).abs() > 0.01) {
            hasChanges = true;
            break;
          }
        }
      } else {
        hasChanges = true;
      }

      if (hasChanges) {
        setState(() {
          samples = List.of(_backgroundSamples);
        });
      }
    } else {
      final isSpeaking = widget.participant?.isSpeaking ?? false;

      if (isSpeaking) {
        // 1. Simulate a human vocal burst (syllable)
        // Pick a random global volume between 30% and 100% for this exact moment
        final syllableVolume = _random.nextDouble() * 0.7 + 0.3;

        final centerIndex = widget.options.barCount / 2;

        final newSamples = List<double>.generate(widget.options.barCount, (i) {
          // 2. Create an EQ bell-curve (center bars are louder/taller)
          final distance = (i - centerIndex).abs();
          final shapeWeight = 1.0 - (distance * 0.15);

          // 3. Add high-frequency micro-jitter to each specific bar
          // This ensures the bars don't all move in perfect unison
          // 90% to 100% multiplier
          final jitter = _random.nextDouble() * 0.9 + 0.1;

          final value = syllableVolume * shapeWeight * jitter;
          return clampDouble(value, 0, 1);
        });

        setState(() {
          samples = newSamples;
        });
        _lastSimulatedLevel = 1.0;
      } else if (_lastSimulatedLevel > 0) {
        _lastSimulatedLevel = 0.0;
        setState(() {
          samples = List.filled(widget.options.barCount, 0);
        });
      }
    }
  }

  @override
  void didUpdateWidget(SoundWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final didUpdateParams =
        oldWidget.participant?.sid != widget.participant?.sid ||
        oldWidget.audioTrack?.sid != widget.audioTrack?.sid ||
        oldWidget.options != widget.options;

    if (didUpdateParams) {
      _detachListeners();
      _attachListeners();
    }
  }

  @override
  void dispose() {
    _uiThrottleTimer?.cancel();
    _controller.dispose();
    _detachListeners();
    super.dispose();
  }

  Color _getColorForThinkingState(
    BuildContext context,
    int index,
    int activeIndex,
  ) {
    final distance = (index - activeIndex).abs();
    final maxDistance = samples.length / 4;
    final gradientStrength = clampDouble(1 - (distance / maxDistance), 0, 1);
    final alpha =
        widget.options.barMinOpacity +
        (gradientStrength * (1 - widget.options.barMinOpacity));

    return widget.options.computeColor(context).withValues(alpha: alpha);
  }

  Color _getColorForListeningState(
    BuildContext context,
    int index,
    int centerIndex,
  ) {
    const baseAlpha = 0.1;
    final alpha = index == centerIndex
        ? baseAlpha + (_pulseAnimation.value - baseAlpha)
        : baseAlpha;

    return widget.options.computeColor(context).withValues(alpha: alpha);
  }

  List<BarsViewItem> _createBarsViewItems(
    int length,
    Color Function(int) colorProvider,
  ) {
    return List.generate(
      length,
      (i) => BarsViewItem(
        value: samples[i],
        color: colorProvider(i),
      ),
    );
  }

  List<BarsViewItem> _generateElements(
    BuildContext context,
    VisualizerState state,
  ) {
    final baseColor = widget.options.computeColor(context);
    final centerIndex = (samples.length / 2).floor();

    if (state == VisualizerState.active) {
      final samplesChanged =
          _lastSamples == null ||
          _lastSamples!.length != samples.length ||
          !listEquals(_lastSamples, samples);

      if (_cachedBarItems != null && _lastState == state && !samplesChanged) {
        return _cachedBarItems!;
      }

      _lastSamples = List.of(samples);
      _lastState = state;
      _cachedBarItems = _createBarsViewItems(samples.length, (_) => baseColor);
      return _cachedBarItems!;
    }

    _lastState = state;
    switch (state) {
      case VisualizerState.thinking:
        final activeIndex = (_pulseAnimation.value * (samples.length - 1))
            .round();
        return _createBarsViewItems(
          samples.length,
          (i) => _getColorForThinkingState(context, i, activeIndex),
        );

      case VisualizerState.listening:
        return _createBarsViewItems(
          samples.length,
          (i) => _getColorForListeningState(context, i, centerIndex),
        );

      case VisualizerState.active:
        return _cachedBarItems!;
    }
  }

  VisualizerState _determineState() {
    if (widget.participant == null) return VisualizerState.listening;
    return VisualizerState.active;
  }

  @override
  Widget build(BuildContext context) {
    final state = _determineState();

    if (state == VisualizerState.active) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      final elements = _generateElements(context, state);
      return BarsView(
        options: widget.options,
        elements: elements,
      );
    }

    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (ctx, _) {
        final elements = _generateElements(ctx, state);
        return BarsView(
          options: widget.options,
          elements: elements,
        );
      },
    );
  }
}

class BarsViewItem {
  const BarsViewItem({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;
}

class BarsView extends StatelessWidget {
  const BarsView({
    required this.options,
    required this.elements,
    super.key,
  });
  final AudioVisualizerWidgetOptions options;
  final List<BarsViewItem> elements;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final delta = (constraints.maxWidth / elements.length) - options.spacing;

      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: options.spacing,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < elements.length; i++)
            Center(
              child: AnimatedContainer(
                width: 1,
                duration: Duration(
                  milliseconds:
                      options.durationInMilliseconds ~/ options.barCount,
                ),
                decoration: BoxDecoration(
                  color: elements[i].color,
                  borderRadius: BorderRadius.circular(options.cornerRadius),
                ),
                height: clampDouble(
                  math.max(
                    delta,
                    (elements[i].value * (constraints.maxHeight - delta)) +
                        delta,
                  ),
                  0,
                  options.maxHeight,
                ),
              ),
            ),
        ],
      );
    },
  );
}
