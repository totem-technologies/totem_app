import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/utils/first_frame.dart';
import 'package:web/web.dart' as web;

import 'benchmark_config.dart';
import 'benchmark_room.dart';
import 'looping_video.dart';

@JS('roomBenchmarkConfigure')
external set _configure(JSFunction callback);
@JS('roomBenchmarkStart')
external set _start(JSFunction callback);
@JS('roomBenchmarkStop')
external set _stop(JSFunction callback);
@JS('roomBenchmarkReady')
external set _ready(JSBoolean value);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const attribution = bool.fromEnvironment('BENCHMARK_ATTRIBUTION');
  debugProfileBuildsEnabledUserWidgets = attribution;
  debugProfileLayoutsEnabled = attribution;
  debugProfilePaintsEnabled = attribution;
  runApp(const _BenchmarkApp());
}

class _BenchmarkApp extends StatefulWidget {
  const _BenchmarkApp();

  @override
  State<_BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<_BenchmarkApp> {
  BenchmarkConfig _config = BenchmarkConfig.fromQuery(Uri.base.queryParameters);
  bool _recording = false;
  int _startMicros = 0;
  int? _endMicros;
  Completer<void>? _flushed;
  final List<FrameTiming> _frames = [];

  int get _nowMicros => (web.window.performance.now() * 1000).round();

  void _timings(List<FrameTiming> frames) {
    if (!_recording) return;
    for (final frame in frames) {
      if (frame.timestampInMicroseconds(FramePhase.vsyncStart) < _startMicros) {
        continue;
      }
      if (_endMicros != null &&
          frame.timestampInMicroseconds(FramePhase.rasterFinish) >
              _endMicros!) {
        if (!(_flushed?.isCompleted ?? true)) _flushed!.complete();
        continue;
      }
      if (_frames.length < 36000) _frames.add(frame);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_timings);
    _configure = ((JSString query) {
      final config = BenchmarkConfig.fromQuery(
        Uri.splitQueryString(query.toDart),
      );
      setState(() => _config = config);
    }).toJS;
    _start = (() {
      _frames.clear();
      _startMicros = _nowMicros;
      _endMicros = null;
      _recording = true;
    }).toJS;
    _stop = (() => _stopRecording().toJS).toJS;
    waitForFirstRasterizedFrame(
      rasterized: WidgetsBinding.instance.waitUntilFirstFrameRasterized,
      scheduleFrame: WidgetsBinding.instance.scheduleForcedFrame,
    ).then((_) {
      if (mounted) _ready = true.toJS;
    });
  }

  Future<JSString> _stopRecording() async {
    _endMicros = _nowMicros;
    _flushed = Completer<void>();
    // Flush the engine's final timing batch outside the measurement window.
    final timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      WidgetsBinding.instance.scheduleForcedFrame();
    });
    try {
      await _flushed!.future.timeout(const Duration(seconds: 5));
    } finally {
      timer.cancel();
    }
    _recording = false;
    return jsonEncode({
      'config': _config.toJson(),
      'elapsedMs': (_endMicros! - _startMicros) / 1000,
      'flutterFrames': _frames.length,
      'buildMs': [
        for (final f in _frames) f.buildDuration.inMicroseconds / 1000,
      ],
      'rasterMs': [
        for (final f in _frames) f.rasterDuration.inMicroseconds / 1000,
      ],
    }).toJS;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: BenchmarkRoom(
      config: _config,
      videoBuilder: (id, mode) => mode == VideoMode.hidden
          ? const ColoredBox(color: Colors.black)
          : LoopingVideo(
              key: ValueKey(id),
              participant: id,
              mode: mode,
              rounded: _config.clip == TileClip.css,
            ),
    ),
  );
}
