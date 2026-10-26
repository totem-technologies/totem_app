import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/media/local_audio_level.dart';
import 'package:totem_core/features/sessions/media/speech_level.dart';
import 'package:web/web.dart' as web;

/// Every analyser shares one context; browsers limit how many can run.
web.AudioContext? _audioContext;

/// Five frequency-band levels for an [AudioTrack], read from the browser
/// audio graph.
///
/// A complete time-domain window supplies the overall microphone loudness,
/// while Web Audio frequency data provides the distinct bar heights. This
/// mirrors the native visualizer more closely than splitting a short window
/// into time slices.
Stream<List<double>> localAudioLevels(
  AudioTrack track, {
  required int barCount,
}) {
  Timer? timer;
  web.MediaStreamAudioSourceNode? source;
  web.AnalyserNode? analyser;
  late final StreamController<List<double>> controller;
  controller = StreamController<List<double>>(
    onListen: () {
      final context = _audioContext ??= web.AudioContext();
      if (context.state == 'suspended') {
        // Safari refuses to resume outside a user gesture. The bars then read
        // silence until a later mount resumes the context.
        unawaited(context.resume().toDart.then((_) {}, onError: (_) {}));
      }
      final jsTrack = (track.mediaStreamTrack as MediaStreamTrackWeb).jsTrack;
      source = context.createMediaStreamSource(web.MediaStream([jsTrack].toJS));
      // About 21 ms at 48 kHz, close to the 20 ms packets whose levels the
      // browser reports for the remote bars.
      final node = context.createAnalyser()..fftSize = 1024;
      source!.connect(node);
      analyser = node;

      final timeDomainBuffer = JSFloat32Array.withLength(node.fftSize);
      final frequencyBuffer = JSFloat32Array.withLength(node.frequencyBinCount);
      final timeDomainSamples = timeDomainBuffer.toDart;
      final frequencySamples = frequencyBuffer.toDart;
      final bandRanges = _frequencyBandRanges(
        sampleRate: context.sampleRate,
        fftSize: node.fftSize,
        frequencyBinCount: node.frequencyBinCount,
        barCount: barCount,
      );
      final meter = SpeechLevelMeter();
      var shownLoudness = 0.0;
      var shown = List<double>.filled(barCount, 0, growable: false);
      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        node.getFloatTimeDomainData(timeDomainBuffer);
        final loudness = heldSpeechLevel(
          shownLoudness,
          meter.level(rmsDb(timeDomainSamples)),
        );
        shownLoudness = loudness;
        node.getFloatFrequencyData(frequencyBuffer);
        final measured = frequencyBandLevels(
          _frequencyBandDecibels(frequencySamples, bandRanges),
          loudness,
        );
        final next = heldSpeechLevels(shown, measured);
        if (listEquals(next, shown)) return;
        shown = next;
        controller.add(next);
      });
    },
    onCancel: () {
      timer?.cancel();
      source?.disconnect();
      analyser?.disconnect();
    },
  );
  return controller.stream;
}

List<({int start, int end})> _frequencyBandRanges({
  required double sampleRate,
  required int fftSize,
  required int frequencyBinCount,
  required int barCount,
}) {
  const minimumFrequency = 80.0;
  final maximumFrequency = math.min(4000.0, sampleRate / 2);
  final bandRatio = math.pow(
    maximumFrequency / minimumFrequency,
    1 / barCount,
  );
  return [
    for (var index = 0; index < barCount; index++)
      (
        start: _frequencyBin(
          minimumFrequency * math.pow(bandRatio, index),
          sampleRate: sampleRate,
          fftSize: fftSize,
          frequencyBinCount: frequencyBinCount,
        ),
        end: _frequencyBin(
          minimumFrequency * math.pow(bandRatio, index + 1),
          sampleRate: sampleRate,
          fftSize: fftSize,
          frequencyBinCount: frequencyBinCount,
        ),
      ),
  ];
}

int _frequencyBin(
  num frequency, {
  required double sampleRate,
  required int fftSize,
  required int frequencyBinCount,
}) {
  final bin = (frequency * fftSize / sampleRate).round();
  return bin.clamp(1, frequencyBinCount - 1);
}

List<double> _frequencyBandDecibels(
  Float32List frequencySamples,
  List<({int start, int end})> ranges,
) => [
  for (final range in ranges)
    _frequencyBandDecibelsForRange(frequencySamples, range),
];

double _frequencyBandDecibelsForRange(
  Float32List frequencySamples,
  ({int start, int end}) range,
) {
  var power = 0.0;
  var samples = 0;
  for (var index = range.start; index <= range.end; index++) {
    final decibels = frequencySamples[index];
    if (!decibels.isFinite) continue;
    power += math.pow(10, decibels / 10);
    samples++;
  }
  if (samples == 0) return double.negativeInfinity;
  return 10 * math.log(power / samples) / math.ln10;
}
