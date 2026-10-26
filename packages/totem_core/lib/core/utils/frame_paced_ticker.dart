import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A shared 30 Hz clock for small indicators that do not need display-rate
/// animation. Defers frame requests themselves, while Ticker still supplies
/// frame timestamps and AnimationController retains its interpolation behavior.
class FramePacedTicker extends Ticker {
  FramePacedTicker(super._onTick, {super.debugLabel});

  static const interval = Duration(microseconds: 33334);
  static final _pending = <FramePacedTicker>{};
  static Timer? _clock;

  @override
  bool get scheduled => _pending.contains(this) || super.scheduled;

  @override
  void scheduleTick({bool rescheduling = false}) {
    assert(
      shouldScheduleTick,
      'Only active, unscheduled tickers may request a tick.',
    );
    _pending.add(this);
    _clock ??= Timer.periodic(interval, (_) {
      // A pending Flutter frame can be delayed, including while the app is
      // backgrounded. Do not keep waking the clock without new tick requests.
      if (_pending.isEmpty) {
        _stopClock();
        return;
      }
      final tickers = _pending.toList(growable: false);
      _pending.clear();
      for (final ticker in tickers) {
        ticker._requestFrame();
      }
    });
  }

  void _requestFrame() {
    if (shouldScheduleTick) super.scheduleTick();
  }

  @override
  void unscheduleTick() {
    _pending.remove(this);
    if (_pending.isEmpty) _stopClock();
    super.unscheduleTick();
  }

  static void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }
}

/// Supplies one paced ticker, respecting the subtree's TickerMode. The
/// AnimationController owns and disposes the ticker.
mixin FramePacedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  Ticker? _pacedTicker;

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(
      _pacedTicker == null,
      'Only one ticker may be created by this State.',
    );
    final mode = TickerMode.getValuesNotifier(context).value;
    return _pacedTicker = FramePacedTicker(onTick)
      ..forceFrames = mode.forceFrames
      ..muted = !mode.enabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = TickerMode.valuesOf(context);
    _pacedTicker
      ?..forceFrames = mode.forceFrames
      ..muted = !mode.enabled;
  }

  @override
  void dispose() {
    // An implicit animation State disposes its controller in super.dispose().
    super.dispose();
    assert(
      _pacedTicker == null || !_pacedTicker!.isActive,
      'The animation controller must be disposed with its owning State.',
    );
    _pacedTicker = null;
  }
}
