import 'dart:async';

import 'package:checks/checks.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/services/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

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
      check(values).isEmpty();

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      check(values).deepEquals([false]);
      initialCheck.complete(const [ConnectivityResult.wifi]);
      await tester.pump();
      check(values).deepEquals([false]);
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
      check(values).isEmpty();

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      check(values).deepEquals([true]);
    });

    testWidgets('combines confirmed, distinct connectivity changes', (
      tester,
    ) async {
      final connectivity = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      var currentConnectivity = const [ConnectivityResult.wifi];
      addTearDown(changes.close);
      when(
        connectivity.checkConnectivity,
      ).thenAnswer((_) async => currentConnectivity);
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

      check(await container.read(isOfflineProvider.future)).equals(false);

      changes.add(const [ConnectivityResult.none]);
      await tester.pump();
      changes.add(const [ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 500));

      check(values).deepEquals([false]);
    });

    testWidgets('ignores a stale offline confirmation after reconnecting', (
      tester,
    ) async {
      final connectivity = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      final confirmation = Completer<List<ConnectivityResult>>();
      var checks = 0;
      addTearDown(changes.close);
      when(connectivity.checkConnectivity).thenAnswer((_) {
        if (checks++ == 0) {
          return Future.value(const [ConnectivityResult.wifi]);
        }
        return confirmation.future;
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

      check(await container.read(isOfflineProvider.future)).equals(false);

      changes.add(const [ConnectivityResult.none]);
      await tester.pump(const Duration(milliseconds: 500));
      changes.add(const [ConnectivityResult.wifi]);
      await tester.pump();
      confirmation.complete(const [ConnectivityResult.none]);
      await tester.pump();

      check(values).deepEquals([false]);
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
      check(container.read(isOfflineProvider).value).equals(false);

      currentCheck.complete(const [ConnectivityResult.none]);
      await pumpEventQueue();
      check(container.read(isOfflineProvider).value).equals(false);
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
        final connectivity = _MockConnectivity();
        final changes = StreamController<List<ConnectivityResult>>();
        final resumedCheck = Completer<List<ConnectivityResult>>();
        var checks = 0;
        addTearDown(changes.close);
        when(connectivity.checkConnectivity).thenAnswer((_) {
          checks++;
          if (checks < 3) {
            return Future.value(const [ConnectivityResult.none]);
          }
          return resumedCheck.future;
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
