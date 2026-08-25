import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/widgets/offline_indicator.dart';
import 'package:totem_core/core/services/connectivity_service.dart';

void main() {
  Future<void> pumpIndicator(WidgetTester tester, Stream<bool> connectivity) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [isOfflineProvider.overrideWith((ref) => connectivity)],
        child: const MaterialApp(
          home: OfflineIndicatorPage(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
  }

  testWidgets('does not show a banner when initially online', (tester) async {
    await pumpIndicator(tester, Stream.value(false));
    await tester.pumpAndSettle();

    expect(find.text("You're Offline"), findsNothing);
    expect(find.text("You're back online"), findsNothing);
  });

  testWidgets('shows offline and reconnection transitions', (tester) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    await pumpIndicator(tester, connectivity.stream);

    connectivity.add(true);
    await tester.pumpAndSettle();
    expect(find.text("You're Offline"), findsOneWidget);

    connectivity.add(false);
    await tester.pumpAndSettle();
    expect(find.text("You're Offline"), findsNothing);
    expect(find.text("You're back online"), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text("You're back online"), findsNothing);
  });

  testWidgets('stays offline when connectivity drops during reconnection', (
    tester,
  ) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    await pumpIndicator(tester, connectivity.stream);

    connectivity.add(true);
    await tester.pumpAndSettle();
    connectivity.add(false);
    await tester.pumpAndSettle();
    expect(find.text("You're back online"), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    connectivity.add(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text("You're Offline"), findsOneWidget);
    expect(find.text("You're back online"), findsNothing);
  });
}
