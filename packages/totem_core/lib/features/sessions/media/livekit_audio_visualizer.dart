// file copied from livekit_components package and modified

import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';

/// Level bars for an [audioTrack], analysed on this device by the LiveKit
/// SDK visualizer. Restarts the visualizer if it stops reporting.
class SoundWaveformWidget extends StatefulWidget {
  const new({
    required this.audioTrack,
    required this.barCount,
    required this.color,
    super.key,
  });
  final sdk.AudioTrack audioTrack;
  final int barCount;
  final Color color;

  @override
  State<SoundWaveformWidget> createState() => _SoundWaveformWidgetState();
}

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

class _SoundWaveformWidgetState extends State<SoundWaveformWidget> {
  static const Duration _watchdogInterval = Duration(seconds: 2);
  static const Duration _baseRestartCooldown = Duration(seconds: 3);
  static const Duration _maxRestartCooldown = Duration(seconds: 30);
  static const int _maxConsecutiveRestartAttempts = 6;

  List<double> samples = <double>[];
  List<double> _backgroundSamples = <double>[];
  Timer? _pendingUiUpdate;
  Timer? _visualizerWatchdogTimer;

  sdk.AudioVisualizer? _visualizer;
  sdk.EventsListener<sdk.AudioVisualizerEvent>? _visualizerListener;

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
    if (widget.audioTrack.muted) return false;
    if (_visualizer == null) return true;
    final lastEventAt = _lastVisualizerEventAt;
    if (lastEventAt == null) return true;
    return DateTime.now().difference(lastEventAt) > const Duration(seconds: 3);
  }

  Future<void> _disposeResources({
    sdk.AudioVisualizer? visualizer,
    sdk.EventsListener<sdk.AudioVisualizerEvent>? visualizerListener,
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
  }

  Future<void> _detachListeners() async {
    final visualizerListener = _visualizerListener;
    final visualizer = _visualizer;
    _visualizerListener = null;
    _visualizer = null;
    await _disposeResources(
      visualizer: visualizer,
      visualizerListener: visualizerListener,
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
    _backgroundSamples = List.filled(widget.barCount, 0, growable: false);
    if (!mounted) return;
    setState(() {
      samples = List.filled(widget.barCount, 0, growable: false);
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

    samples = List.filled(widget.barCount, 0, growable: false);
    _backgroundSamples = List.filled(widget.barCount, 0, growable: false);

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
    sdk.AudioVisualizer? visualizer;
    sdk.EventsListener<sdk.AudioVisualizerEvent>? visualizerListener;

    try {
      if (!mounted || generation != _listenerGeneration) return;

      visualizer = sdk.createVisualizer(
        widget.audioTrack,
        options: sdk.AudioVisualizerOptions(barCount: widget.barCount),
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
        );
        return;
      }
      _lastVisualizerEventAt ??= DateTime.now();
      _visualizer = visualizer;
      _visualizerListener = visualizerListener;
    } catch (error, stackTrace) {
      await _disposeResources(
        visualizer: visualizer,
        visualizerListener: visualizerListener,
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
    if (!identical(oldWidget.audioTrack, widget.audioTrack) ||
        oldWidget.barCount != widget.barCount) {
      _reattachListeners();
    }
  }

  @override
  void dispose() {
    _pendingUiUpdate?.cancel();
    _visualizerWatchdogTimer?.cancel();
    _listenerGeneration++;
    _lifecycle = _lifecycle.then((_) => _detachListeners());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LevelBars(levels: samples, color: widget.color);
}
