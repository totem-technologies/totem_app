// file copied from livekit_components package and modified

import 'dart:async';
import 'dart:math' show max;

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

const agentStateAttributeKey = 'lk.agent.state';

class _SoundWaveformWidgetState extends State<SoundWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  List<double> samples = <double>[];
  List<double> _backgroundSamples = <double>[];
  Timer? _uiThrottleTimer;

  sdk.AudioVisualizer? _visualizer;
  sdk.EventsListener<sdk.AudioVisualizerEvent>? _visualizerListener;
  sdk.EventsListener<sdk.ParticipantEvent>? _participantListener;

  // Agent support
  sdk.AgentState _agentState = sdk.AgentState.initializing;

  // Cached bar items to avoid allocations every frame
  List<BarsViewItem>? _cachedBarItems;
  VisualizerState? _lastState;
  List<double>? _lastSamples;

  Future<void> _detachListeners() async {
    try {
      if (_visualizer != null) {
        // TODO(bdlukaa): This is not closing visualizer correctly, causing spamming.
        // Do not stop before dispose. https://github.com/livekit/client-sdk-flutter/issues/800#issuecomment-3765712228
        try {
          await _visualizer?.stop();
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Failed to stop visualizer',
          );
        }

        // try {
        //   await _visualizer?.dispose();
        // } catch (error, stackTrace) {
        //   ErrorHandler.logError(
        //     error,
        //     stackTrace: stackTrace,
        //     message: 'Failed to dispose visualizer',
        //   );
        // }
      }
    } finally {
      _visualizer = null;

      try {
        await _visualizerListener?.dispose();
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to dispose visualizer listener',
        );
      }
      _visualizerListener = null;

      try {
        await _participantListener?.dispose();
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to dispose participant listener',
        );
      }
      _participantListener = null;
    }
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

    // THE UI LOOP: Runs safely at ~7-8 FPS (every 140ms) instead of per-packet
    _uiThrottleTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (!mounted) return;

      bool hasChanges = false;

      // Only trigger a rebuild if the volume delta is large enough to see (> 1%)
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
    });

    _attachListeners();
  }

  Future<void> _attachListeners() async {
    try {
      if (widget.participant != null) {
        _participantListener = widget.participant!.createListener();
        _participantListener?.on<sdk.TrackMutedEvent>((e) {
          if (!mounted) return;
          _backgroundSamples = List.filled(widget.options.barCount, 0);
          setState(() {
            samples = List.filled(widget.options.barCount, 0);
          });
        });

        if (widget.participant?.kind == sdk.ParticipantKind.AGENT) {
          _participantListener?.on<sdk.ParticipantAttributesChanged>((e) {
            if (!mounted) return;
            final agentAttributes = sdk.AgentAttributes.fromJson(e.attributes);
            setState(() {
              _agentState =
                  agentAttributes.lkAgentState ?? sdk.AgentState.initializing;
            });
          });
        }
      }

      if (widget.audioTrack != null) {
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

    // For active state, only regenerate if samples changed
    // This avoids creating new objects every animation frame
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

    // For thinking/listening states, we need animation so regenerate
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
        return _cachedBarItems!; // Already handled above
    }
  }

  VisualizerState _determineState() {
    if (widget.participant?.kind == sdk.ParticipantKind.AGENT &&
        _agentState == sdk.AgentState.thinking) {
      return VisualizerState.thinking;
    }

    if (widget.participant == null ||
        widget.participant?.kind == sdk.ParticipantKind.AGENT &&
            (_agentState == sdk.AgentState.initializing ||
                _agentState == sdk.AgentState.listening)) {
      return VisualizerState.listening;
    }

    return VisualizerState.active;
  }

  @override
  Widget build(BuildContext context) {
    final state = _determineState();

    // Only use AnimatedBuilder when animation is needed (thinking/listening)
    // For active state, just rebuild when samples change via setState
    if (state == VisualizerState.active) {
      // Stop animation to save CPU when not needed
      if (_controller.isAnimating) {
        _controller.stop();
      }
      final elements = _generateElements(context, state);
      return BarsView(
        options: widget.options,
        elements: elements,
      );
    }

    // Resume animation for thinking/listening states
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
                  max(
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
