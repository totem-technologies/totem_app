import 'dart:math' as math;
import 'dart:typed_data';

/// The quietest level, in dBFS, the bars show. Background noise stays below
/// it once the browser's noise suppression has run, while LiveKit already
/// counts a speaker as active from -35 dB.
const _quietestDb = -45.0;

/// The level, in dBFS, that fills the bars.
const _loudestDb = -15.0;

/// Bar height between 0 and 1 for a sound level in dBFS. Local and remote
/// levels share this scale, so the same voice looks the same everywhere.
/// Heights move in steps of 0.05 so small fluctuations don't redraw.
double speechLevel(double db) {
  final level = ((db - _quietestDb) / (_loudestDb - _quietestDb)).clamp(
    0.0,
    1.0,
  );
  return (level * 20).round() / 20;
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
