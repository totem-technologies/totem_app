import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/services/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isOfflineConnectivity', () {
    test('treats empty and none results as offline', () {
      expect(isOfflineConnectivity(const []), isTrue);
      expect(
        isOfflineConnectivity(const [ConnectivityResult.none]),
        isTrue,
      );
    });

    test('treats available transports as online', () {
      expect(
        isOfflineConnectivity(const [ConnectivityResult.wifi]),
        isFalse,
      );
      expect(
        isOfflineConnectivity(const [
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
        isFalse,
      );
    });
  });

  test('checkIsOffline falls back to online when the plugin fails', () async {
    final connectivity = _MockConnectivity();
    when(connectivity.checkConnectivity).thenThrow(Exception('unavailable'));

    expect(await checkIsOffline(connectivity), isFalse);
  });

  group('isOfflineProvider', () {
    testWidgets('filters a transient initial offline result', (tester) async {
      final connectivity = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      final initialCheck = Completer<List<ConnectivityResult>>();
      var checks = 0;
      addTearDown(changes.close);
      when(connectivity.checkConnectivity).thenAnswer((_) {
        if (checks++ == 0) return initialCheck.future;
        return Future.value(const [ConnectivityResult.wifi]);
      });
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => changes.stream);

      final container = ProviderContainer(
        overrides: [connectivityProvider.overrideWithValue(connectivity)],
      );
      addTearDown(container.dispose);
      final values = <bool>[];
      final subscription = container.listen(
        isOfflineProvider,
        (_, next) => next.whenData(values.add),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      changes.add(const [ConnectivityResult.none]);
      await tester.pump();
      expect(values, isEmpty);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(values, [false]);
      initialCheck.complete(const [ConnectivityResult.wifi]);
      await tester.pump();
      expect(values, [false]);
    });

    testWidgets('publishes a confirmed initial offline result', (tester) async {
      final connectivity = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      addTearDown(changes.close);
      when(
        connectivity.checkConnectivity,
      ).thenAnswer((_) async => const [ConnectivityResult.none]);
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => changes.stream);

      final container = ProviderContainer(
        overrides: [connectivityProvider.overrideWithValue(connectivity)],
      );
      addTearDown(container.dispose);
      final values = <bool>[];
      final subscription = container.listen(
        isOfflineProvider,
        (_, next) => next.whenData(values.add),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await tester.pump();
      expect(values, isEmpty);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(values, [true]);
    });

    test('combines the current check and distinct stream changes', () async {
      final connectivity = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      addTearDown(changes.close);
      when(
        connectivity.checkConnectivity,
      ).thenAnswer((_) async => const [ConnectivityResult.wifi]);
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => changes.stream);

      final container = ProviderContainer(
        overrides: [connectivityProvider.overrideWithValue(connectivity)],
      );
      addTearDown(container.dispose);
      final values = <bool>[];
      final subscription = container.listen(
        isOfflineProvider,
        (_, next) => next.whenData(values.add),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(isOfflineProvider.future);
      changes.add(const [ConnectivityResult.none]);
      await pumpEventQueue();
      changes.add(const []);
      await pumpEventQueue();
      changes.add(const [ConnectivityResult.mobile]);
      await pumpEventQueue();

      expect(values, [false, true, false]);
    });

    test('ignores a stale check after a newer stream update', () async {
      final connectivity = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      final currentCheck = Completer<List<ConnectivityResult>>();
      addTearDown(changes.close);
      when(
        connectivity.checkConnectivity,
      ).thenAnswer((_) => currentCheck.future);
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => changes.stream);

      final container = ProviderContainer(
        overrides: [connectivityProvider.overrideWithValue(connectivity)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        isOfflineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      changes.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(container.read(isOfflineProvider).value, isFalse);

      currentCheck.complete(const [ConnectivityResult.none]);
      await pumpEventQueue();
      expect(container.read(isOfflineProvider).value, isFalse);
    });

    testWidgets('refreshes the current status when the app resumes', (
      tester,
    ) async {
      final connectivity = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      var checks = 0;
      addTearDown(changes.close);
      when(connectivity.checkConnectivity).thenAnswer((_) async {
        return checks++ == 0
            ? const [ConnectivityResult.wifi]
            : const [ConnectivityResult.none];
      });
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => changes.stream);

      final container = ProviderContainer(
        overrides: [connectivityProvider.overrideWithValue(connectivity)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        isOfflineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(await container.read(isOfflineProvider.future), isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(checks, 2);
      expect(container.read(isOfflineProvider).value, isTrue);
    });
  });
}
