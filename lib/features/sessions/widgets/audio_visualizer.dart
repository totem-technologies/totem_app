// file copied from livekit_components package and modified
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart';
import 'package:provider/provider.dart';
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

class AudioVisualizerWidget extends StatelessWidget {
  const AudioVisualizerWidget({
    super.key,
    this.backgroundColor = Colors.transparent,
    this.options = const AudioVisualizerWidgetOptions(),
  });
  final AudioVisualizerWidgetOptions options;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => Consumer<TrackReferenceContext?>(
    builder:
        (
          BuildContext context,
          TrackReferenceContext? trackCtx,
          Widget? child,
        ) => ColoredBox(
          color: backgroundColor,
          child: SoundWaveformWidget(
            audioTrack: trackCtx?.audioTrack,
            participant: trackCtx?.participant,
            options: options,
          ),
        ),
  );
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
  List<double> samples = [];

  sdk.AudioVisualizer? _visualizer;
  sdk.EventsListener<sdk.AudioVisualizerEvent>? _visualizerListener;
  sdk.EventsListener<sdk.ParticipantEvent>? _participantListener;

  // Agent support
  sdk.AgentState _agentState = sdk.AgentState.initializing;

  @override
  void didUpdateWidget(SoundWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final didUpdateParams =
        oldWidget.participant?.sid != widget.participant?.sid ||
        oldWidget.audioTrack?.sid != widget.audioTrack?.sid ||
        oldWidget.options != widget.options;

    if (didUpdateParams) {
      // Re-attach listeners
      _detachListeners();
      _attachListeners();
    }
  }

  Future<void> _attachListeners() async {
    try {
      if (widget.participant != null) {
        _participantListener = widget.participant!.createListener();
        _participantListener?.on<sdk.TrackMutedEvent>((e) {
          if (!mounted) return;
          setState(() {
            samples = List.filled(widget.options.barCount, 0);
          });
        });

        // If participant is agent, listen to agent state changes
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
          setState(() {
            samples = element.event
                .where((event) => event != null && event is num)
                .map((event) => (event! as num).toDouble())
                .toList();
          });
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

  Future<void> _detachListeners() async {
    try {
      if (_visualizer != null) {
        try {
          await _visualizer?.stop();
          await _visualizer?.dispose();
        } catch (_) {}
        _visualizer = null;
      }

      await _visualizerListener?.dispose();
      _visualizerListener = null;
      await _participantListener?.dispose();
      _participantListener = null;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to dettach audio visualizer listeners',
      );
    }
  }

  @override
  void initState() {
    super.initState();

    samples = List.filled(widget.options.barCount, 0, growable: false);

    _controller = AnimationController(
      duration: Duration(milliseconds: widget.options.durationInMilliseconds),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _attachListeners();
  }

  @override
  void dispose() {
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
        return _createBarsViewItems(samples.length, (_) => baseColor);
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
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (ctx, _) {
        final state = _determineState();
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
