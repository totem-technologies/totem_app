// file copied from livekit_components package and modified

import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';

/// Level bars for an [audioTrack], analysed on this device by the LiveKit
/// SDK visualizer. Restarts the visualizer if it stops reporting.
class SoundWaveformWidget extends StatefulWidget {
  const SoundWaveformWidget({
    required this.audioTrack,
    required this.barCount,
    required this.color,
    this.sampleLevels,
    super.key,
  });
  final sdk.AudioTrack audioTrack;
  final int barCount;
  final Color color;

  @visibleForTesting
  final Stream<List<double>>? sampleLevels;

  @override
  State<SoundWaveformWidget> createState() => _SoundWaveformWidgetState();
}

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

/// Ignores room noise while preserving an active waveform until speech falls
/// below a lower release threshold.
bool waveformIsActive(List<double> samples, {required bool wasActive}) {
  const activationThreshold = 0.04;
  const releaseThreshold = 0.02;
  final threshold = wasActive ? releaseThreshold : activationThreshold;
  return samples.any((sample) => sample >= threshold);
}

/// Applies hysteresis on the Web Audio meter's 0.05-step scale.
bool webWaveformIsActive(List<double> levels, {required bool wasActive}) {
  const activationThreshold = 0.15;
  const releaseThreshold = 0.05;
  final threshold = wasActive ? releaseThreshold : activationThreshold;
  return levels.any((level) => level >= threshold);
}

@visibleForTesting
class AudioVisualizerCircuitBreaker {
  bool _permanentlyUnavailable = false;

  bool get canAttempt => !_permanentlyUnavailable;

  void recordFailure(Object error) {
    if (error is MissingPluginException ||
        error is PlatformException && error.code == 'unimplemented') {
      _permanentlyUnavailable = true;
    }
  }
}

final _audioVisualizerCircuitBreaker = AudioVisualizerCircuitBreaker();

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
  StreamSubscription<List<double>>? _sampleSubscription;

  int _listenerGeneration = 0;
  Future<void> _lifecycle = Future.value();
  DateTime? _lastUiUpdateAt;
  DateTime? _lastVisualizerEventAt;
  DateTime? _lastRestartAttemptAt;
  int _consecutiveRestartAttempts = 0;
  bool _visualizerUnavailable = false;
  bool _isSpeaking = false;

  Future<void> _safeAsyncAction(
    AsyncCallback action, {
    required String failureMessage,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      // Cleanup follows a failed visualizer start or widget teardown. Preserve
      // the root start failure as the report and keep cleanup diagnostics local.
      debugPrint('$failureMessage: $error\n$stackTrace');
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
    if (widget.sampleLevels != null ||
        _visualizerUnavailable ||
        widget.audioTrack.muted) {
      return false;
    }
    if (_visualizer == null) return true;
    final lastEventAt = _lastVisualizerEventAt;
    if (lastEventAt == null) return true;
    return DateTime.now().difference(lastEventAt) > const Duration(seconds: 3);
  }

  Future<void> _disposeResources({
    sdk.AudioVisualizer? visualizer,
    sdk.EventsListener<sdk.AudioVisualizerEvent>? visualizerListener,
    StreamSubscription<List<double>>? sampleSubscription,
  }) async {
    await _safeAsyncAction(
      () async => await sampleSubscription?.cancel(),
      failureMessage: 'Failed to cancel visualizer sample subscription',
    );
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
    final sampleSubscription = _sampleSubscription;
    _visualizerListener = null;
    _visualizer = null;
    _sampleSubscription = null;
    await _disposeResources(
      visualizer: visualizer,
      visualizerListener: visualizerListener,
      sampleSubscription: sampleSubscription,
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
      _isSpeaking = false;
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
    final isSpeaking = waveformIsActive(
      _backgroundSamples,
      wasActive: _isSpeaking,
    );
    final nextSamples = isSpeaking
        ? _backgroundSamples
        : List<double>.filled(widget.barCount, 0, growable: false);
    if (!audioVisualizerSamplesChanged(samples, nextSamples) &&
        isSpeaking == _isSpeaking) {
      return;
    }
    setState(() {
      samples = List<double>.of(nextSamples, growable: false);
      _isSpeaking = isSpeaking;
    });
  }

  @override
  void initState() {
    super.initState();

    samples = List.filled(widget.barCount, 0, growable: false);
    _backgroundSamples = List.filled(widget.barCount, 0, growable: false);

    if (widget.sampleLevels == null) {
      _visualizerWatchdogTimer = Timer.periodic(_watchdogInterval, (_) {
        if (!mounted || !_hasStalledVisualizer) return;
        if (!_audioVisualizerCircuitBreaker.canAttempt ||
            _consecutiveRestartAttempts >= _maxConsecutiveRestartAttempts) {
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
    }

    _reattachListeners();
  }

  void _receiveSamples(List<Object?> values) {
    final sampleCount = min(_backgroundSamples.length, values.length);
    var index = 0;
    for (final value in values.take(sampleCount)) {
      _backgroundSamples[index++] = value is num ? value.toDouble() : 0;
    }
    for (var i = sampleCount; i < _backgroundSamples.length; i++) {
      _backgroundSamples[i] = 0;
    }
    _scheduleUiUpdate();
  }

  Future<void> _attachListeners({required int generation}) async {
    sdk.AudioVisualizer? visualizer;
    sdk.EventsListener<sdk.AudioVisualizerEvent>? visualizerListener;

    try {
      if (!mounted ||
          generation != _listenerGeneration ||
          !_audioVisualizerCircuitBreaker.canAttempt) {
        _visualizerUnavailable = true;
        return;
      }

      final sampleLevels = widget.sampleLevels;
      if (sampleLevels != null) {
        await _sampleSubscription?.cancel();
        _sampleSubscription = sampleLevels.listen((samples) {
          if (!mounted || generation != _listenerGeneration) return;
          _receiveSamples(samples);
        });
        return;
      }

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
          _receiveSamples(element.event);
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
      _audioVisualizerCircuitBreaker.recordFailure(error);
      _visualizerUnavailable = !_audioVisualizerCircuitBreaker.canAttempt;
      ErrorHandler.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to attach audio visualizer listeners',
        incidentKey: 'audio-visualizer:${error.runtimeType}',
        diagnostics: {
          'feature': 'audio_visualizer',
          'recovery': _visualizerUnavailable ? 'unavailable' : 'retrying',
          'restart_attempt': _consecutiveRestartAttempts,
        },
      );
    }
  }

  @override
  void didUpdateWidget(SoundWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.audioTrack, widget.audioTrack) ||
        oldWidget.barCount != widget.barCount ||
        oldWidget.sampleLevels != widget.sampleLevels) {
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
