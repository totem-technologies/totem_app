import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/widgets/offline_indicator.dart';
import 'package:totem_core/core/services/connectivity_service.dart';

void main() {
  Future<void> pumpIndicator(
    WidgetTester tester,
    Stream<bool> connectivity, {
    Widget child = const Scaffold(body: SizedBox.expand()),
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [isOfflineProvider.overrideWith((ref) => connectivity)],
        child: MaterialApp(home: OfflineIndicatorPage(child: child)),
      ),
    );
  }

  testWidgets('does not show a banner when initially online', (tester) async {
    await pumpIndicator(tester, Stream.value(false));
    await tester.pumpAndSettle();

    check(tester.widgetList(find.text("You're Offline"))).length.equals(0);
    check(tester.widgetList(find.text("You're back online"))).length.equals(0);
  });

  testWidgets('shows offline and reconnection transitions', (tester) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    await pumpIndicator(tester, connectivity.stream);

    connectivity.add(true);
    await tester.pumpAndSettle();
    check(tester.widgetList(find.text("You're Offline"))).length.equals(1);

    connectivity.add(false);
    await tester.pumpAndSettle();
    check(tester.widgetList(find.text("You're Offline"))).length.equals(0);
    check(tester.widgetList(find.text("You're back online"))).length.equals(1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    check(tester.widgetList(find.text("You're back online"))).length.equals(0);
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
    check(tester.widgetList(find.text("You're back online"))).length.equals(1);

    await tester.pump(const Duration(seconds: 1));
    connectivity.add(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    check(tester.widgetList(find.text("You're Offline"))).length.equals(1);
    check(tester.widgetList(find.text("You're back online"))).length.equals(0);
  });

  testWidgets('collapses the status-bar inset with the banner', (tester) async {
    const contentKey = ValueKey('content');
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPadding);

    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    await pumpIndicator(
      tester,
      connectivity.stream,
      child: const ColoredBox(key: contentKey, color: Colors.transparent),
    );

    connectivity.add(true);
    await tester.pumpAndSettle();
    connectivity.add(false);
    await tester.pumpAndSettle();

    final contentTopBeforeCollapse = tester.getTopLeft(find.byKey(contentKey));
    await tester.pump(const Duration(seconds: 3));

    check(
      tester.getTopLeft(find.byKey(contentKey)),
    ).equals(contentTopBeforeCollapse);

    await tester.pump(const Duration(milliseconds: 175));
    check(
      tester.getTopLeft(find.byKey(contentKey)).dy,
    ).isLessThan(contentTopBeforeCollapse.dy);
  });
}
