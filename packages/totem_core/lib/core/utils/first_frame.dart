import 'dart:async';

/// Waits for rasterization while ensuring web frame timings can be delivered.
///
/// The web engine batches timings for 100 ms and only flushes them on a rendered
/// frame. A static first frame can otherwise leave the rasterization future
/// pending indefinitely. Request frames only until that future completes.
Future<void> waitForFirstRasterizedFrame({
  required Future<void> rasterized,
  required void Function() scheduleFrame,
}) async {
  final timer = Timer.periodic(
    const Duration(milliseconds: 150),
    (_) => scheduleFrame(),
  );
  try {
    await rasterized;
  } finally {
    timer.cancel();
  }
}
