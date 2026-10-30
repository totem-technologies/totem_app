import 'dart:math' as math;

import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart'
    show webWaveformIsActive;
import 'package:totem_core/features/sessions/media/local_audio_level.dart';

/// Deterministic talker whose levels pass through the same shaping as the
/// Web microphone meter: band levels on a 0.05 scale, held while falling, and
/// gated by the speech hysteresis. Phrases of 1.5–4 s with 4–6 syllables per
/// second alternate with pauses of 0.3–1.2 s.
class SyntheticSpeech {
  SyntheticSpeech(int seed, {this.barCount = 5}) : _random = math.Random(seed);

  /// The Web meter's sample period.
  static const interval = Duration(milliseconds: 100);

  final int barCount;
  final math.Random _random;

  var _talking = false;
  var _segmentSamples = 0;
  var _syllableSamples = 0;
  var _syllablePeak = 0.0;
  var _shownLoudness = 0.0;
  late var _shown = List<double>.filled(barCount, 0);
  var _active = false;

  double _between(double low, double high) =>
      low + (high - low) * _random.nextDouble();

  /// The next sample's bar levels, between 0 and 1.
  List<double> next() {
    if (_segmentSamples <= 0) {
      _talking = !_talking;
      _segmentSamples = (_talking ? _between(15, 40) : _between(3, 12)).round();
    }
    _segmentSamples--;

    var loudness = 0.0;
    if (_talking) {
      if (_syllableSamples <= 0) {
        _syllableSamples = _random.nextBool() ? 2 : 3;
        _syllablePeak = _between(0.45, 1);
      }
      // Syllables open at their peak and decay before the next one.
      loudness = _syllablePeak * (0.55 + 0.45 * (_syllableSamples / 3));
      _syllableSamples--;
    }
    loudness = (loudness * 20).round() / 20;
    _shownLoudness = heldSpeechLevel(_shownLoudness, loudness);

    // Voice energy falls with frequency, with per-sample formant variation.
    final decibels = [
      for (var band = 0; band < barCount; band++)
        -12.0 - band * 4 + _between(-5, 5),
    ];
    _shown = heldSpeechLevels(
      _shown,
      frequencyBandLevels(decibels, _shownLoudness),
    );
    _active = webWaveformIsActive(_shown, wasActive: _active);
    return _active ? List.of(_shown) : List<double>.filled(barCount, 0);
  }
}
