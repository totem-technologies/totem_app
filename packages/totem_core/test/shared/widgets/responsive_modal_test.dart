import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester, {required Size size}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openModal(
    WidgetTester tester, {
    required WidgetBuilder bottomSheetBuilder,
    required WidgetBuilder largeScreenBuilder,
    bool showDragHandle = false,
  }) async {
    final context = tester.element(find.byType(SizedBox));
    final modal = showResponsiveModal<void>(
      context: context,
      showDragHandle: showDragHandle,
      bottomSheetBuilder: bottomSheetBuilder,
      largeScreenBuilder: largeScreenBuilder,
    );

    addTearDown(() async {
      if (find.byType(BottomSheet).evaluate().isNotEmpty ||
          find.byType(Dialog).evaluate().isNotEmpty) {
        await tester
            .state<NavigatorState>(find.byType(Navigator).last)
            .maybePop();
        await tester.pumpAndSettle();
      }
      unawaited(modal);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpAndSettle();
  }

  group('showResponsiveModal', () {
    testWidgets('uses a bottom sheet on small screens', (tester) async {
      await pumpHost(tester, size: const Size(500, 900));
      await openModal(
        tester,
        showDragHandle: true,
        bottomSheetBuilder: (context) => const Text('Small modal'),
        largeScreenBuilder: (context) => const Text('Large modal'),
      );

      check(tester.widgetList(find.text('Small modal'))).length.equals(1);
      check(tester.widgetList(find.text('Large modal'))).length.equals(0);
      check(tester.widgetList(find.byType(BottomSheet))).length.equals(1);
      check(tester.widgetList(find.byType(Dialog))).length.equals(0);
    });

    testWidgets('uses a dialog on large screens', (tester) async {
      await pumpHost(tester, size: const Size(900, 900));
      await openModal(
        tester,
        bottomSheetBuilder: (context) => const Text('Small modal'),
        largeScreenBuilder: (context) => const Text('Large modal'),
      );

      check(tester.widgetList(find.text('Large modal'))).length.equals(1);
      check(tester.widgetList(find.text('Small modal'))).length.equals(0);
      check(tester.widgetList(find.byType(Dialog))).length.equals(1);
      check(tester.widgetList(find.byType(BottomSheet))).length.equals(0);
    });
  });
}
