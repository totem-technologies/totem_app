// file copied from livekit_components package and modified

import 'dart:async';
import 'dart:math' show max, min;

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/errors/error_handler.dart';

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

@visibleForTesting
bool audioVisualizerSamplesChanged(List<double> current, List<double> next) {
  if (current.length != next.length) return true;
  for (var i = 0; i < current.length; i++) {
    if ((current[i] - next[i]).abs() > 0.01 ||
        (current[i] != 0 && next[i] == 0)) {
      return true;
    }
  }
  return false;
}

class _SoundWaveformWidgetState extends State<SoundWaveformWidget>
    with SingleTickerProviderStateMixin {
  static const Duration _watchdogInterval = Duration(seconds: 2);
  static const Duration _baseRestartCooldown = Duration(seconds: 3);
  static const Duration _maxRestartCooldown = Duration(seconds: 30);
  static const int _maxConsecutiveRestartAttempts = 6;

  late AnimationController _controller;
  late CurvedAnimation _pulseAnimation;

  List<double> samples = <double>[];
  List<double> _backgroundSamples = <double>[];
  Timer? _pendingUiUpdate;
  Timer? _visualizerWatchdogTimer;

  sdk.AudioVisualizer? _visualizer;
  sdk.EventsListener<sdk.AudioVisualizerEvent>? _visualizerListener;
  sdk.EventsListener<sdk.ParticipantEvent>? _participantListener;

  // Agent support
  sdk.AgentState _agentState = sdk.AgentState.initializing;

  // Cached bar items to avoid allocations every frame
  List<BarsViewItem>? _cachedBarItems;
  VisualizerState? _lastState;
  List<double>? _lastSamples;

  int _listenerGeneration = 0;
  Future<void> _lifecycle = Future.value();
  DateTime? _lastUiUpdateAt;
  DateTime? _lastVisualizerEventAt;
  DateTime? _lastRestartAttemptAt;
  int _consecutiveRestartAttempts = 0;

  Future<void> _safeAsyncAction(
    AsyncCallback action, {
    required String failureMessage,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: failureMessage,
      );
    }
  }

  Duration get _currentRestartCooldown {
    final exponent = min(_consecutiveRestartAttempts, 4);
    final factor = 1 << exponent;
    final cooldown = Duration(
      milliseconds: _baseRestartCooldown.inMilliseconds * factor,
    );
    if (cooldown > _maxRestartCooldown) {
      return _maxRestartCooldown;
    }
    return cooldown;
  }

  bool get _hasStalledVisualizer {
    if (widget.audioTrack == null || widget.audioTrack!.muted) return false;
    if (_visualizer == null) return true;
    final lastEventAt = _lastVisualizerEventAt;
    if (lastEventAt == null) return true;
    return DateTime.now().difference(lastEventAt) > const Duration(seconds: 3);
  }

  Future<void> _disposeResources({
    sdk.AudioVisualizer? visualizer,
    sdk.EventsListener<sdk.AudioVisualizerEvent>? visualizerListener,
    sdk.EventsListener<sdk.ParticipantEvent>? participantListener,
  }) async {
    await _safeAsyncAction(
      () async => await visualizerListener?.dispose(),
      failureMessage: 'Failed to dispose visualizer listener',
    );
    if (visualizer != null) {
      await _safeAsyncAction(
        visualizer.stop,
        failureMessage: 'Failed to stop visualizer',
      );
      await _safeAsyncAction(
        visualizer.dispose,
        failureMessage: 'Failed to dispose visualizer',
      );
    }
    await _safeAsyncAction(
      () async => await participantListener?.dispose(),
      failureMessage: 'Failed to dispose participant listener',
    );
  }

  Future<void> _detachListeners() async {
    final visualizerListener = _visualizerListener;
    final visualizer = _visualizer;
    final participantListener = _participantListener;
    _visualizerListener = null;
    _visualizer = null;
    _participantListener = null;
    await _disposeResources(
      visualizer: visualizer,
      visualizerListener: visualizerListener,
      participantListener: participantListener,
    );
  }

  void _reattachListeners() {
    final generation = ++_listenerGeneration;
    _lifecycle = _lifecycle.then((_) async {
      await _detachListeners();
      if (!mounted || generation != _listenerGeneration) return;
      _resetSamples();
      await _attachListeners(generation: generation);
    });
  }

  void _resetSamples() {
    _pendingUiUpdate?.cancel();
    _pendingUiUpdate = null;
    _lastUiUpdateAt = null;
    _lastVisualizerEventAt = null;
    _backgroundSamples = List.filled(
      widget.options.barCount,
      0,
      growable: false,
    );
    if (!mounted) return;
    setState(() {
      samples = List.filled(widget.options.barCount, 0, growable: false);
      _cachedBarItems = null;
      _lastSamples = null;
    });
  }

  void _scheduleUiUpdate() {
    if (!mounted || _pendingUiUpdate != null) return;

    const minimumInterval = Duration(milliseconds: 140);
    final lastUpdateAt = _lastUiUpdateAt;
    final elapsed = lastUpdateAt == null
        ? minimumInterval
        : DateTime.now().difference(lastUpdateAt);
    if (elapsed >= minimumInterval) {
      _flushUiUpdate();
      return;
    }

    _pendingUiUpdate = Timer(minimumInterval - elapsed, () {
      _pendingUiUpdate = null;
      _flushUiUpdate();
    });
  }

  void _flushUiUpdate() {
    if (!mounted) return;
    _lastUiUpdateAt = DateTime.now();
    if (!_samplesChanged()) return;
    setState(() {
      samples = List<double>.of(_backgroundSamples, growable: false);
    });
  }

  bool _samplesChanged() =>
      audioVisualizerSamplesChanged(samples, _backgroundSamples);

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

    _visualizerWatchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      if (!mounted || !_hasStalledVisualizer) return;
      if (_consecutiveRestartAttempts >= _maxConsecutiveRestartAttempts) {
        return;
      }

      final now = DateTime.now();
      final lastAttempt = _lastRestartAttemptAt;
      if (lastAttempt != null &&
          now.difference(lastAttempt) < _currentRestartCooldown) {
        return;
      }

      _lastRestartAttemptAt = now;
      _consecutiveRestartAttempts++;
      _reattachListeners();
    });

    _reattachListeners();
  }

  Future<void> _attachListeners({required int generation}) async {
    sdk.EventsListener<sdk.ParticipantEvent>? participantListener;
    sdk.AudioVisualizer? visualizer;
    sdk.EventsListener<sdk.AudioVisualizerEvent>? visualizerListener;

    try {
      if (!mounted || generation != _listenerGeneration) return;

      final participant = widget.participant;
      if (participant != null) {
        participantListener = participant.createListener()
          ..on<sdk.TrackMutedEvent>((event) {
            if (!mounted ||
                generation != _listenerGeneration ||
                event.publication.source != sdk.TrackSource.microphone) {
              return;
            }
            _resetSamples();
          });

        if (participant.kind == sdk.ParticipantKind.AGENT) {
          participantListener.on<sdk.ParticipantAttributesChanged>((event) {
            if (!mounted || generation != _listenerGeneration) return;
            final agentAttributes = sdk.AgentAttributes.fromJson(
              event.attributes,
            );
            setState(() {
              _agentState =
                  agentAttributes.lkAgentState ?? sdk.AgentState.initializing;
            });
          });
        }
      }

      final audioTrack = widget.audioTrack;
      if (audioTrack != null) {
        visualizer = sdk.createVisualizer(
          audioTrack,
          options: sdk.AudioVisualizerOptions(
            barCount: widget.options.barCount,
            centeredBands: widget.options.centeredBands,
          ),
        );

        visualizerListener = visualizer.createListener()
          ..on<sdk.AudioVisualizerEvent>((element) {
            if (!mounted || generation != _listenerGeneration) return;

            _lastVisualizerEventAt = DateTime.now();
            _lastRestartAttemptAt = null;
            _consecutiveRestartAttempts = 0;
            final events = element.event;
            final sampleCount = min(_backgroundSamples.length, events.length);
            for (var i = 0; i < sampleCount; i++) {
              final value = events[i];
              _backgroundSamples[i] = value is num ? value.toDouble() : 0;
            }
            for (var i = sampleCount; i < _backgroundSamples.length; i++) {
              _backgroundSamples[i] = 0;
            }
            _scheduleUiUpdate();
          });

        await visualizer.start();
        if (!mounted || generation != _listenerGeneration) {
          await _disposeResources(
            visualizer: visualizer,
            visualizerListener: visualizerListener,
            participantListener: participantListener,
          );
          return;
        }
        _lastVisualizerEventAt ??= DateTime.now();
      }

      if (!mounted || generation != _listenerGeneration) {
        await _disposeResources(
          visualizer: visualizer,
          visualizerListener: visualizerListener,
          participantListener: participantListener,
        );
        return;
      }
      _participantListener = participantListener;
      _visualizer = visualizer;
      _visualizerListener = visualizerListener;
    } catch (error, stackTrace) {
      await _disposeResources(
        visualizer: visualizer,
        visualizerListener: visualizerListener,
        participantListener: participantListener,
      );
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
        !identical(oldWidget.participant, widget.participant) ||
        oldWidget.participant?.sid != widget.participant?.sid ||
        !identical(oldWidget.audioTrack, widget.audioTrack) ||
        oldWidget.audioTrack?.sid != widget.audioTrack?.sid ||
        oldWidget.options != widget.options;

    if (didUpdateParams) {
      _reattachListeners();
    }
  }

  @override
  void dispose() {
    _pendingUiUpdate?.cancel();
    _visualizerWatchdogTimer?.cancel();
    _listenerGeneration++;
    _pulseAnimation.dispose();
    _controller.dispose();
    _lifecycle = _lifecycle.then((_) => _detachListeners());
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
      (i) => BarsViewItem(value: samples[i], color: colorProvider(i)),
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
      return BarsView(options: widget.options, elements: elements);
    }

    // Resume animation for thinking/listening states
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (ctx, _) {
        final elements = _generateElements(ctx, state);
        return BarsView(options: widget.options, elements: elements);
      },
    );
  }
}

class BarsViewItem {
  const BarsViewItem({required this.value, required this.color});

  final double value;
  final Color color;
}

class BarsView extends StatelessWidget {
  const BarsView({required this.options, required this.elements, super.key});
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
