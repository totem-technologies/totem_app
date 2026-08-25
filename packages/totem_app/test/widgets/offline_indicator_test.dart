import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/widgets/offline_indicator.dart';
import 'package:totem_core/core/services/connectivity_service.dart';

void main() {
  testWidgets('keeps a startup online event over a stale initial check', (
    tester,
  ) async {
    final initialConnectivity = Completer<bool>();
    final connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivityChanges.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) => initialConnectivity.future),
          connectivityStreamProvider.overrideWith(
            (ref) => connectivityChanges.stream,
          ),
        ],
        child: const MaterialApp(
          home: OfflineIndicatorPage(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
    await tester.pump();

    connectivityChanges.add(const [ConnectivityResult.wifi]);
    await tester.pump();
    initialConnectivity.complete(true);
    await tester.pumpAndSettle();

    expect(find.text("You're Offline"), findsNothing);
    expect(find.text("You're back online"), findsNothing);
  });

  testWidgets('shows reconnected after a real offline to online transition', (
    tester,
  ) async {
    final connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivityChanges.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) async => true),
          connectivityStreamProvider.overrideWith(
            (ref) => connectivityChanges.stream,
          ),
        ],
        child: const MaterialApp(
          home: OfflineIndicatorPage(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("You're Offline"), findsOneWidget);

    connectivityChanges.add(const [ConnectivityResult.wifi]);
    await tester.pumpAndSettle();

    expect(find.text("You're Offline"), findsNothing);
    expect(find.text("You're back online"), findsOneWidget);
  });

  testWidgets('stays offline when connectivity drops during reconnection', (
    tester,
  ) async {
    final connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivityChanges.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) async => true),
          connectivityStreamProvider.overrideWith(
            (ref) => connectivityChanges.stream,
          ),
        ],
        child: const MaterialApp(
          home: OfflineIndicatorPage(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    connectivityChanges.add(const [ConnectivityResult.wifi]);
    await tester.pumpAndSettle();
    expect(find.text("You're back online"), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    connectivityChanges.add(const [ConnectivityResult.none]);
    await tester.pumpAndSettle();
    expect(find.text("You're Offline"), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text("You're Offline"), findsOneWidget);
    expect(find.text("You're back online"), findsNothing);
  });

  testWidgets('does not show reconnected while connectivity initializes', (
    tester,
  ) async {
    final initialConnectivity = Completer<bool>();
    final connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivityChanges.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) => initialConnectivity.future),
          connectivityStreamProvider.overrideWith(
            (ref) => connectivityChanges.stream,
          ),
        ],
        child: const MaterialApp(
          home: OfflineIndicatorPage(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
    await tester.pump();

    connectivityChanges.add(const [ConnectivityResult.none]);
    await tester.pumpAndSettle();
    expect(find.text("You're Offline"), findsOneWidget);

    connectivityChanges.add(const [ConnectivityResult.wifi]);
    await tester.pumpAndSettle();

    expect(find.text("You're back online"), findsNothing);
    expect(find.text("You're Offline"), findsNothing);

    initialConnectivity.complete(false);
    await tester.pumpAndSettle();

    expect(find.text("You're back online"), findsNothing);
  });

  testWidgets('refreshes connectivity after returning to the shell route', (
    tester,
  ) async {
    var connectivityChecks = 0;
    final resumedConnectivity = Completer<bool>();
    final connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivityChanges.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) {
            if (connectivityChecks++ == 0) return false;
            return resumedConnectivity.future;
          }),
          connectivityStreamProvider.overrideWith(
            (ref) => connectivityChanges.stream,
          ),
        ],
        child: MaterialApp(
          home: OfflineIndicatorPage(
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            body: Center(
                              child: FilledButton(
                                onPressed: Navigator.of(context).pop,
                                child: const Text('Go back'),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open route'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're Offline"), findsNothing);
    connectivityChanges.add(const [ConnectivityResult.none]);
    await tester.pumpAndSettle();
    expect(find.text("You're Offline"), findsOneWidget);

    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    connectivityChanges.add(const [ConnectivityResult.none]);
    await tester.pump();
    resumedConnectivity.complete(false);
    await tester.pumpAndSettle();

    expect(find.text("You're Offline"), findsNothing);
    expect(find.text("You're back online"), findsOneWidget);
  });

  testWidgets('refreshes connectivity when the app resumes', (tester) async {
    var connectivityChecks = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) async {
            return connectivityChecks++ > 0;
          }),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream<List<ConnectivityResult>>.empty(),
          ),
        ],
        child: const MaterialApp(
          home: OfflineIndicatorPage(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(connectivityChecks, 1);
    expect(find.text("You're Offline"), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(connectivityChecks, 2);
    expect(find.text("You're Offline"), findsOneWidget);
  });
}
