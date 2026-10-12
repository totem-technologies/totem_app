import 'dart:math' as math;
import 'dart:typed_data';

export 'local_audio_bands_stub.dart'
    if (dart.library.js_interop) 'local_audio_bands_web.dart';

/// Levels below this read as silence, so microphone noise doesn't keep the
/// bars moving.
const _noiseFloor = 0.15;

/// Turns an analyser's byte frequency spectrum (0 to 255 per bin) into
/// [bandCount] levels between 0 and 1 over the speech range, with the lowest
/// band in the middle and higher ones alternating outwards.
List<double> speechBands(Uint8List spectrum, int bandCount) {
  // The speech range is the bottom sixth of the spectrum (about 4 kHz at
  // common sample rates), the same share the SDK visualizer used.
  final speechBins = math.max(bandCount, (spectrum.length * 170 / 1024).ceil());
  final binsPerBand = speechBins / bandCount;
  final ordered = List<double>.filled(bandCount, 0);
  for (var band = 0; band < bandCount; band++) {
    final start = (band * binsPerBand).floor();
    final end = math.max(start + 1, ((band + 1) * binsPerBand).floor());
    var sum = 0;
    for (var bin = start; bin < end && bin < spectrum.length; bin++) {
      sum += spectrum[bin];
    }
    final level = math.sqrt(sum / ((end - start) * 255));
    ordered[band] = level < _noiseFloor ? 0 : level;
  }

  final centered = List<double>.filled(bandCount, 0);
  var right = bandCount ~/ 2;
  var left = right;
  for (var band = 0; band < bandCount; band++) {
    if (band.isEven) {
      centered[right++] = ordered[band];
    } else {
      centered[--left] = ordered[band];
    }
  }
  return centered;
}

/// Whether [next] differs from [previous] enough to be worth redrawing.
bool speechBandsChanged(List<double> previous, List<double> next) {
  if (previous.length != next.length) return true;
  for (var i = 0; i < next.length; i++) {
    if ((previous[i] - next[i]).abs() > 0.05) return true;
  }
  return false;
}
