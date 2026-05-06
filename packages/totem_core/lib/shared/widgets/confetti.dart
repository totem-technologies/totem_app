import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';

class ConfettiController {
  static Timer? _confettiTimer;

  static void showConfetti(BuildContext context) {
    if (!context.mounted) return;

    double randomInRange(double min, double max) {
      return min + Random().nextDouble() * (max - min);
    }

    const total = 10;
    var progress = 0;
    _confettiTimer?.cancel();
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!context.mounted) {
        timer.cancel();
        _confettiTimer = null;
        return;
      }
      progress++;

      if (progress >= total) {
        timer.cancel();
        _confettiTimer = null;
        return;
      }

      final count = ((1 - progress / total) * 50).toInt();

      Confetti.launch(
        context,
        options: ConfettiOptions(
          particleCount: count,
          startVelocity: 30,
          spread: 360,
          ticks: 60,
          x: randomInRange(0.1, 0.3),
          y: Random().nextDouble() - 0.2,
        ),
      );
      Confetti.launch(
        context,
        options: ConfettiOptions(
          particleCount: count,
          startVelocity: 30,
          spread: 360,
          ticks: 60,
          x: randomInRange(0.7, 0.9),
          y: Random().nextDouble() - 0.2,
        ),
      );
    });
  }
}
