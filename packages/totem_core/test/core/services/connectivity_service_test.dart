import 'dart:async';

import 'package:checks/checks.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/services/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _ConnectivityHarness {
  _ConnectivityHarness({
    required AsyncValueGetter<List<ConnectivityResult>> checkConnectivity,
  }) {
    when(connectivity.checkConnectivity).thenAnswer((_) => checkConnectivity());
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => changes.stream);

    container = ProviderContainer(
      overrides: [connectivityProvider.overrideWithValue(connectivity)],
    );
    subscription = container.listen(
      isOfflineProvider,
      (_, next) => next.whenData(values.add),
      fireImmediately: true,
    );
  }

  final connectivity = _MockConnectivity();
  final changes = StreamController<List<ConnectivityResult>>();
  final values = <bool>[];
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<bool>> subscription;

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    await changes.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isOfflineConnectivity', () {
    test('treats empty and none results as offline', () {
      check(isOfflineConnectivity(const [])).equals(true);
      check(
        isOfflineConnectivity(const [ConnectivityResult.none]),
      ).equals(true);
    });

    test('treats available transports as online', () {
      check(
        isOfflineConnectivity(const [ConnectivityResult.wifi]),
      ).equals(false);
      check(
        isOfflineConnectivity(const [
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
      ).equals(false);
    });
  });

  test('checkIsOffline falls back to online when the plugin fails', () async {
    final connectivity = _MockConnectivity();
    when(connectivity.checkConnectivity).thenThrow(Exception('unavailable'));

    check(await checkIsOffline(connectivity)).equals(false);
  });

  group('isOfflineProvider', () {
    testWidgets('filters a transient initial offline result', (tester) async {
      final initialCheck = Completer<List<ConnectivityResult>>();
      var checks = 0;
      final harness = _ConnectivityHarness(
        checkConnectivity: () {
          if (checks++ == 0) return initialCheck.future;
          return Future.value(const [ConnectivityResult.wifi]);
        },
      );
      addTearDown(harness.dispose);
      final changes = harness.changes;
      final values = harness.values;

      changes.add(const [ConnectivityResult.none]);
      await tester.pump();
      check(values).isEmpty();

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      check(values).deepEquals([false]);
      initialCheck.complete(const [ConnectivityResult.wifi]);
      await tester.pump();
      check(values).deepEquals([false]);
    });

    testWidgets('publishes a confirmed initial offline result', (tester) async {
      final harness = _ConnectivityHarness(
        checkConnectivity: () async => const [ConnectivityResult.none],
      );
      addTearDown(harness.dispose);
      final values = harness.values;

      await tester.pump();
      check(values).isEmpty();

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      check(values).deepEquals([true]);
    });

    testWidgets('combines confirmed, distinct connectivity changes', (
      tester,
    ) async {
      var currentConnectivity = const [ConnectivityResult.wifi];
      final harness = _ConnectivityHarness(
        checkConnectivity: () async => currentConnectivity,
      );
      addTearDown(harness.dispose);
      final changes = harness.changes;
      final values = harness.values;

      await harness.container.read(isOfflineProvider.future);
      currentConnectivity = const [ConnectivityResult.none];
      changes.add(const [ConnectivityResult.none]);
      await tester.pump();
      check(values).deepEquals([false]);

      changes.add(const []);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      check(values).deepEquals([false, true]);

      currentConnectivity = const [ConnectivityResult.mobile];
      changes.add(const [ConnectivityResult.mobile]);
      await tester.pump();

      check(values).deepEquals([false, true, false]);
    });

    testWidgets('filters a transient offline result after initialization', (
      tester,
    ) async {
      final harness = _ConnectivityHarness(
        checkConnectivity: () async => const [ConnectivityResult.wifi],
      );
      addTearDown(harness.dispose);
      final changes = harness.changes;
      final values = harness.values;

      check(
        await harness.container.read(isOfflineProvider.future),
      ).equals(false);

      changes.add(const [ConnectivityResult.none]);
      await tester.pump();
      changes.add(const [ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 500));

      check(values).deepEquals([false]);
    });

    testWidgets('ignores a stale offline confirmation after reconnecting', (
      tester,
    ) async {
      final confirmation = Completer<List<ConnectivityResult>>();
      var checks = 0;
      final harness = _ConnectivityHarness(
        checkConnectivity: () {
          if (checks++ == 0) {
            return Future.value(const [ConnectivityResult.wifi]);
          }
          return confirmation.future;
        },
      );
      addTearDown(harness.dispose);
      final changes = harness.changes;
      final values = harness.values;

      check(
        await harness.container.read(isOfflineProvider.future),
      ).equals(false);

      changes.add(const [ConnectivityResult.none]);
      await tester.pump(const Duration(milliseconds: 500));
      changes.add(const [ConnectivityResult.wifi]);
      await tester.pump();
      confirmation.complete(const [ConnectivityResult.none]);
      await tester.pump();

      check(values).deepEquals([false]);
    });

    test('ignores a stale check after a newer stream update', () async {
      final currentCheck = Completer<List<ConnectivityResult>>();
      final harness = _ConnectivityHarness(
        checkConnectivity: () => currentCheck.future,
      );
      addTearDown(harness.dispose);
      final changes = harness.changes;
      final container = harness.container;

      changes.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      check(container.read(isOfflineProvider).value).equals(false);

      currentCheck.complete(const [ConnectivityResult.none]);
      await pumpEventQueue();
      check(container.read(isOfflineProvider).value).equals(false);
    });

    testWidgets('refreshes the current status when the app resumes', (
      tester,
    ) async {
      var checks = 0;
      final harness = _ConnectivityHarness(
        checkConnectivity: () async => checks++ == 0
            ? const [ConnectivityResult.wifi]
            : const [ConnectivityResult.none],
      );
      addTearDown(harness.dispose);
      final container = harness.container;

      check(await container.read(isOfflineProvider.future)).equals(false);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      check(checks).equals(2);
      check(container.read(isOfflineProvider).value).equals(false);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      check(checks).equals(3);
      check(container.read(isOfflineProvider).value).equals(true);
    });

    testWidgets(
      'publishes an online resume check after a stale offline event',
      (tester) async {
        final resumedCheck = Completer<List<ConnectivityResult>>();
        var checks = 0;
        final harness = _ConnectivityHarness(
          checkConnectivity: () {
            checks++;
            if (checks < 3) {
              return Future.value(const [ConnectivityResult.none]);
            }
            return resumedCheck.future;
          },
        );
        addTearDown(harness.dispose);
        final changes = harness.changes;
        final container = harness.container;

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        check(container.read(isOfflineProvider).value).equals(true);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        check(checks).equals(3);

        changes.add(const [ConnectivityResult.none]);
        await tester.pump();
        resumedCheck.complete(const [ConnectivityResult.wifi]);
        await tester.pump();

        check(container.read(isOfflineProvider).value).equals(false);
      },
    );
  });
}
