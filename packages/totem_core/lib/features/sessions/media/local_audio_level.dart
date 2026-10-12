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
