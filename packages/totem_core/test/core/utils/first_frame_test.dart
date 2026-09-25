import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/utils/first_frame.dart';

void main() {
  test('requests frames until rasterization, then releases its timer', () {
    fakeAsync((clock) {
      final rasterized = Completer<void>();
      var requests = 0;
      var finished = false;
      waitForFirstRasterizedFrame(
        rasterized: rasterized.future,
        scheduleFrame: () => requests++,
      ).then((_) => finished = true);
      clock.elapse(const Duration(milliseconds: 300));
      check(requests).equals(2);
      check(finished).isFalse();
      rasterized.complete();
      clock
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 1));
      check(requests).equals(2);
      check(finished).isTrue();
      check(clock.periodicTimerCount).equals(0);
    });
  });

  test('releases the timer when rasterization fails', () {
    fakeAsync((clock) {
      final rasterized = Completer<void>();
      final failure = StateError('renderer failed');
      Object? observed;
      waitForFirstRasterizedFrame(
        rasterized: rasterized.future,
        scheduleFrame: () {},
      ).then<void>((_) {}, onError: (Object error) => observed = error);
      rasterized.completeError(failure);
      clock.flushMicrotasks();
      check(observed).identicalTo(failure);
      check(clock.periodicTimerCount).equals(0);
    });
  });
}
