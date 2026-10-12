import 'dart:math' as math;
import 'dart:typed_data';

/// Turns one speaker's sound levels into bar heights, scaled to how loud
/// that speaker has recently been.
///
/// Browsers and microphones capture at very different levels, since each
/// browser applies its own gain control. Scaling to each speaker's own
/// recent peak makes ordinary speech look alike everywhere. The peak decays
/// slowly, so one loud moment stops dominating after a few seconds.
class SpeechLevelMeter {
  /// [now] reads the time; it defaults to a stopwatch started here.
  new({Duration Function()? now}) : _now = now ?? _startStopwatch();

  static Duration Function() _startStopwatch() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Levels below this, in dBFS, are noise for every speaker.
  static const _gateDb = -50.0;

  /// The bars span this many dB below the speaker's recent peak.
  static const _rangeDb = 24.0;

  /// The peak never decays below this, so the bars never reach below the
  /// gate: sound just above it shows a sliver, not a jump. Microphones that
  /// peak lower than this don't fill the bars.
  static const double _quietestPeakDb = _gateDb + _rangeDb;

  /// How fast the remembered peak falls when the speaker gets quieter.
  static const _peakDecayDbPerSecond = 1.5;

  final Duration Function() _now;
  double _peakDb = _quietestPeakDb;
  Duration? _lastReading;

  /// The bar height between 0 and 1 for a sound level in dBFS. Heights move
  /// in steps of 0.05 so small fluctuations don't redraw.
  double level(double db) {
    final now = _now();
    if (_lastReading case final last?) {
      final seconds =
          (now - last).inMicroseconds / Duration.microsecondsPerSecond;
      _peakDb = math.max(
        _quietestPeakDb,
        _peakDb - _peakDecayDbPerSecond * seconds,
      );
    }
    _lastReading = now;
    if (db < _gateDb) return 0;
    _peakDb = math.max(_peakDb, db);
    final level = ((db - (_peakDb - _rangeDb)) / _rangeDb).clamp(0.0, 1.0);
    return (level * 20).round() / 20;
  }
}

/// The level in dBFS of a linear amplitude between 0 and 1, such as the
/// audio levels LiveKit reports for each speaker.
double amplitudeToDb(double amplitude) => amplitude <= 0
    ? double.negativeInfinity
    : 20 * math.log(amplitude) / math.ln10;

/// The RMS level in dBFS of audio samples between -1 and 1.
double rmsDb(Float32List samples) {
  var sumOfSquares = 0.0;
  for (final sample in samples) {
    sumOfSquares += sample * sample;
  }
  if (sumOfSquares == 0) return double.negativeInfinity;
  return 10 * math.log(sumOfSquares / samples.length) / math.ln10;
}
