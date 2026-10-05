import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Detects a sustained burst of uncaught errors, which means the app is stuck
/// failing the same work repeatedly rather than hitting a one-off error.
///
/// On WebKit, a lost WebGL context while an `HtmlElementView` is on screen can
/// leave the Flutter web engine throwing on every frame until the page is
/// reloaded (https://github.com/flutter/flutter/issues/162868, fixed by
/// https://github.com/flutter/flutter/pull/190071 but not yet in stable). The
/// UI is frozen at that point, so recovery has to come from outside Flutter.
///
/// [onStorm] fires at most once: the only remedy is a reload, which discards
/// this detector anyway.
class ErrorStormDetector {
  ErrorStormDetector({
    required this.onStorm,
    this.threshold = 10,
    this.window = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final VoidCallback onStorm;
  final int threshold;
  final Duration window;
  final DateTime Function() _clock;

  final List<DateTime> _recent = [];
  bool _fired = false;

  void record() {
    if (_fired) return;
    final now = _clock();
    _recent
      ..add(now)
      ..removeWhere((time) => now.difference(time) > window);
    if (_recent.length < threshold) return;
    _fired = true;
    _recent.clear();
    onStorm();
  }
}

/// Whether Sentry captured [event] from an error nothing in the app handled.
bool isUnhandledSentryEvent(SentryEvent event) =>
    event.exceptions?.any(
      (exception) => exception.mechanism?.handled == false,
    ) ??
    false;
