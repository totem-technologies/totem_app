import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/popups.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    final hostKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(key: hostKey),
        ),
      ),
    );

    return hostKey.currentContext!;
  }

  group('popup lifecycle', () {
    testWidgets('showPopup auto dismisses after configured duration', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      showPopup(
        context,
        duration: const Duration(milliseconds: 500),
        animationDuration: const Duration(milliseconds: 120),
        builder: (_) {
          return const NotificationPopup(
            icon: TotemIcons.chat,
            title: 'Auto dismiss',
            message: 'This should close automatically',
          );
        },
      );

      await tester.pump();
      expect(find.text('Auto dismiss'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Auto dismiss'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Auto dismiss'), findsNothing);
    });

    testWidgets('showNotificationPopup eventually auto dismisses', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      showNotificationPopup(
        context,
        icon: TotemIcons.chat,
        title: 'Auto dismiss',
        message: 'This should close automatically',
      );

      await tester.pump();
      expect(find.text('Auto dismiss'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('Auto dismiss'), findsNothing);
    });

    testWidgets('showPermanentNotificationPopup stays until dismissed', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = PopupController();

      final dismiss = showPermanentNotificationPopup(
        context,
        controller: controller,
        icon: TotemIcons.pause,
        title: 'Permanent',
        message: 'Will stay visible',
      );

      await tester.pump();
      expect(find.text('Permanent'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Permanent'), findsOneWidget);

      dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Permanent'), findsNothing);
    });

    testWidgets('PopupController dismissAll closes active popups', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = PopupController();

      showNotificationPopup(
        context,
        controller: controller,
        icon: TotemIcons.chat,
        title: 'Ephemeral',
        message: 'Ephemeral message',
      );

      showPermanentNotificationPopup(
        context,
        controller: controller,
        icon: TotemIcons.pause,
        title: 'Persistent',
        message: 'Persistent message',
      );

      await tester.pump();
      expect(find.text('Ephemeral'), findsOneWidget);
      expect(find.text('Persistent'), findsOneWidget);

      controller.dismissAll();
      await tester.pumpAndSettle();

      expect(find.text('Ephemeral'), findsNothing);
      expect(find.text('Persistent'), findsNothing);
    });
  });
}
