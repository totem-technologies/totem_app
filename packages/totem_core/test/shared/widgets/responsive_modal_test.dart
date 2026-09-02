import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required Size size,
  }) async {
    final hostKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(key: hostKey),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('showResponsiveModal', () {
    testWidgets('uses a bottom sheet on small screens', (tester) async {
      await pumpHost(
        tester,
        size: const Size(500, 900),
      );

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

      expect(find.text('Small modal'), findsOneWidget);
      expect(find.text('Large modal'), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('uses a dialog on large screens', (tester) async {
      await pumpHost(
        tester,
        size: const Size(900, 900),
      );

      final context = tester.element(find.byType(SizedBox));

      unawaited(
        showResponsiveModal<void>(
          context: context,
          bottomSheetBuilder: (context) => const Text('Small modal'),
          largeScreenBuilder: (context) => const Text('Large modal'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Large modal'), findsOneWidget);
      expect(find.text('Small modal'), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
