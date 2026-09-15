import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester, {required Size size}) async {
    final hostKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: SizedBox(key: hostKey)),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('showResponsiveModal', () {
    testWidgets('uses a bottom sheet on small screens', (tester) async {
      await pumpHost(tester, size: const Size(500, 900));

      final context = tester.element(find.byType(SizedBox));

      unawaited(
        showResponsiveModal<void>(
          context: context,
          showDragHandle: true,
          bottomSheetBuilder: (context) => const Text('Small modal'),
          largeScreenBuilder: (context) => const Text('Large modal'),
        ),
      );

      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Small modal'))).length.equals(1);
      check(tester.widgetList(find.text('Large modal'))).length.equals(0);
      check(tester.widgetList(find.byType(BottomSheet))).length.equals(1);
      check(tester.widgetList(find.byType(Dialog))).length.equals(0);
    });

    testWidgets('uses a dialog on large screens', (tester) async {
      await pumpHost(tester, size: const Size(900, 900));

      final context = tester.element(find.byType(SizedBox));

      unawaited(
        showResponsiveModal<void>(
          context: context,
          bottomSheetBuilder: (context) => const Text('Small modal'),
          largeScreenBuilder: (context) => const Text('Large modal'),
        ),
      );

      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Large modal'))).length.equals(1);
      check(tester.widgetList(find.text('Small modal'))).length.equals(0);
      check(tester.widgetList(find.byType(Dialog))).length.equals(1);
      check(tester.widgetList(find.byType(BottomSheet))).length.equals(0);
    });
  });
}
