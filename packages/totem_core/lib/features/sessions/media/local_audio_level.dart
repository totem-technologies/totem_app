import 'dart:math' as math;

export 'local_audio_level_stub.dart'
    if (dart.library.js_interop) 'local_audio_level_web.dart';

/// The level to show after measuring [measured] while [shown] is on screen.
/// It rises at once but falls gradually, so the bars don't flicker between
/// words.
double heldSpeechLevel(double shown, double measured) {
  if (measured >= shown) return measured;
  // Stay on the 0.05 steps of SpeechLevelMeter.level.
  return (math.max(measured, shown - 0.15) * 20).round() / 20;
}

/// Shapes relative frequency-band magnitudes by the microphone's loudness.
///
/// The loudest measured band reaches [loudness]; quieter bands preserve their
/// real relative amplitude. Each band blends a little of its immediate
/// neighbours, so a single frequency peak forms a coherent wave instead of
/// an isolated spike. Values are quantized with [heldSpeechLevel]'s 0.05-step
/// scale so imperceptible analyser changes do not redraw the UI.
List<double> frequencyBandLevels(List<double> decibels, double loudness) {
  if (loudness <= 0 || decibels.isEmpty) {
    return List<double>.filled(decibels.length, 0, growable: false);
  }
  final amplitudes = [
    for (final decibel in decibels)
      if (decibel.isFinite) math.pow(10, decibel / 20).toDouble() else 0.0,
  ];
  final smoothed = List<double>.generate(amplitudes.length, (index) {
    var sum = amplitudes[index] * 0.5;
    var weight = 0.5;
    if (index > 0) {
      sum += amplitudes[index - 1] * 0.25;
      weight += 0.25;
    }
    if (index < amplitudes.length - 1) {
      sum += amplitudes[index + 1] * 0.25;
      weight += 0.25;
    }
    return sum / weight;
  }, growable: false);
  final loudest = smoothed.reduce(math.max);
  if (loudest == 0) {
    return List<double>.filled(decibels.length, 0, growable: false);
  }
  return [
    for (final amplitude in smoothed)
      (loudness * amplitude / loudest * 20).round() / 20,
  ];
}

/// Smooths each frequency band independently.
List<double> heldSpeechLevels(List<double> shown, List<double> measured) => [
  for (var i = 0; i < measured.length; i++)
    heldSpeechLevel(i < shown.length ? shown[i] : 0, measured[i]),
];
