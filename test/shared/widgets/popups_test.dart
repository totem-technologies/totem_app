// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('showPopup', () {
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

    testWidgets('showPopup with zero duration stays until manually dismissed', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      final dismiss = showPopup(
        context,
        duration: Duration.zero,
        builder: (_) {
          return const NotificationPopup(
            icon: TotemIcons.chat,
            title: 'No timer',
            message: 'This should stay visible',
          );
        },
      );

      await tester.pump();
      expect(find.text('No timer'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('No timer'), findsOneWidget);

      dismiss();
      await tester.pumpAndSettle();
      expect(find.text('No timer'), findsNothing);
    });

    testWidgets('showPopup respects short duration and animation boundaries', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      showPopup(
        context,
        duration: const Duration(milliseconds: 120),
        animationDuration: const Duration(milliseconds: 80),
        builder: (_) {
          return const NotificationPopup(
            icon: TotemIcons.chat,
            title: 'Timing check',
            message: 'Validate timing behavior',
          );
        },
      );

      await tester.pump();
      expect(find.text('Timing check'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Timing check'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Timing check'), findsNothing);
    });
  });

  group('showDismissiblePopup', () {
    testWidgets('showDismissiblePopup stays visible until dismiss callback', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      final dismiss = showDismissiblePopup(
        context,
        builder: (_) {
          return const NotificationPopup(
            icon: TotemIcons.pause,
            title: 'Dismissible',
            message: 'Manual close only',
          );
        },
      );

      await tester.pump();
      expect(find.text('Dismissible'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Dismissible'), findsOneWidget);

      dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Dismissible'), findsNothing);
    });
  });

  group('showNotificationPopup', () {
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
  });

  group('showPermanentNotificationPopup', () {
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

    testWidgets(
      'showPermanentNotificationPopup can be dismissed immediately after show',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = PopupController();

        final dismiss = showPermanentNotificationPopup(
          context,
          controller: controller,
          icon: TotemIcons.pause,
          title: 'Early dismiss',
          message: 'Should close quickly',
        );

        await tester.pump();
        expect(find.text('Early dismiss'), findsOneWidget);

        dismiss();
        await tester.pumpAndSettle();
        expect(find.text('Early dismiss'), findsNothing);
      },
    );

    testWidgets(
      'showPermanentNotificationPopup dismiss callback is idempotent',
      (
        tester,
      ) async {
        final context = await pumpHost(tester);
        final controller = PopupController();

        final dismiss = showPermanentNotificationPopup(
          context,
          controller: controller,
          icon: TotemIcons.pause,
          title: 'Idempotent',
          message: 'Dismiss can be called multiple times',
        );

        await tester.pump();
        expect(find.text('Idempotent'), findsOneWidget);

        dismiss();
        dismiss();
        controller.dismissAll();
        await tester.pumpAndSettle();

        expect(find.text('Idempotent'), findsNothing);
      },
    );

    testWidgets(
      'PopupController dismissAll closes multiple permanent notifications',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = PopupController();

        showPermanentNotificationPopup(
          context,
          controller: controller,
          icon: TotemIcons.pause,
          title: 'Permanent A',
          message: 'First persistent popup',
        );

        showPermanentNotificationPopup(
          context,
          controller: controller,
          icon: TotemIcons.pause,
          title: 'Permanent B',
          message: 'Second persistent popup',
        );

        await tester.pump();
        expect(find.text('Permanent A'), findsOneWidget);
        expect(find.text('Permanent B'), findsOneWidget);

        await tester.pump(const Duration(seconds: 10));
        expect(find.text('Permanent A'), findsOneWidget);
        expect(find.text('Permanent B'), findsOneWidget);

        controller.dismissAll();
        await tester.pumpAndSettle();

        expect(find.text('Permanent A'), findsNothing);
        expect(find.text('Permanent B'), findsNothing);
      },
    );
  });

  group('PopupController', () {
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

    testWidgets('dismissAll on empty controller is a no-op', (tester) async {
      final controller = PopupController();
      controller.dismissAll();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismissAll affects only its own controller popups', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controllerA = PopupController();
      final controllerB = PopupController();

      showPermanentNotificationPopup(
        context,
        controller: controllerA,
        icon: TotemIcons.pause,
        title: 'Controller A',
        message: 'Owned by controller A',
      );

      showPermanentNotificationPopup(
        context,
        controller: controllerB,
        icon: TotemIcons.pause,
        title: 'Controller B',
        message: 'Owned by controller B',
      );

      await tester.pump();
      expect(find.text('Controller A'), findsOneWidget);
      expect(find.text('Controller B'), findsOneWidget);

      controllerA.dismissAll();
      await tester.pumpAndSettle();
      expect(find.text('Controller A'), findsNothing);
      expect(find.text('Controller B'), findsOneWidget);

      controllerB.dismissAll();
      await tester.pumpAndSettle();
      expect(find.text('Controller B'), findsNothing);
    });

    testWidgets('auto-dismissed popup is safely unregistered from controller', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = PopupController();

      showPopup(
        context,
        controller: controller,
        duration: const Duration(milliseconds: 150),
        animationDuration: const Duration(milliseconds: 80),
        builder: (_) {
          return const NotificationPopup(
            icon: TotemIcons.chat,
            title: 'Auto unregister',
            message: 'Should unregister itself',
          );
        },
      );

      await tester.pump();
      expect(find.text('Auto unregister'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Auto unregister'), findsNothing);

      controller.dismissAll();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('mixed auto and permanent lifecycle is handled correctly', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = PopupController();

      showNotificationPopup(
        context,
        controller: controller,
        icon: TotemIcons.chat,
        title: 'Ephemeral mixed',
        message: 'Auto-dismisses',
      );

      showPermanentNotificationPopup(
        context,
        controller: controller,
        icon: TotemIcons.pause,
        title: 'Permanent mixed',
        message: 'Stays visible',
      );

      await tester.pump();
      expect(find.text('Ephemeral mixed'), findsOneWidget);
      expect(find.text('Permanent mixed'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Ephemeral mixed'), findsNothing);
      expect(find.text('Permanent mixed'), findsOneWidget);

      controller.dismissAll();
      await tester.pumpAndSettle();
      expect(find.text('Permanent mixed'), findsNothing);
    });

    testWidgets('dismiss during animation and dismissAll is race-safe', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = PopupController();

      final dismiss = showPermanentNotificationPopup(
        context,
        controller: controller,
        icon: TotemIcons.pause,
        title: 'Race safe',
        message: 'No double remove issues',
      );

      await tester.pump();
      expect(find.text('Race safe'), findsOneWidget);

      dismiss();
      controller.dismissAll();
      dismiss();
      await tester.pumpAndSettle();

      expect(find.text('Race safe'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics announcements', () {
    testWidgets('showNotificationPopup announces message', (tester) async {
      final context = await pumpHost(tester);
      final announcements = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler(SystemChannels.accessibility, (
            message,
          ) async {
            if (message is Map && message['type'] == 'announce') {
              final data = message['data'];
              if (data is Map && data['message'] is String) {
                announcements.add(data['message'] as String);
              }
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null);
      });

      showNotificationPopup(
        context,
        icon: TotemIcons.chat,
        title: 'Accessible',
        message: 'Ephemeral semantics',
      );

      await tester.pump();
      expect(announcements, contains('New message: Ephemeral semantics'));
    });

    testWidgets('showPermanentNotificationPopup announces message', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = PopupController();
      final announcements = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler(SystemChannels.accessibility, (
            message,
          ) async {
            if (message is Map && message['type'] == 'announce') {
              final data = message['data'];
              if (data is Map && data['message'] is String) {
                announcements.add(data['message'] as String);
              }
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null);
      });

      showPermanentNotificationPopup(
        context,
        controller: controller,
        icon: TotemIcons.pause,
        title: 'Accessible permanent',
        message: 'Persistent semantics',
      );

      await tester.pump();
      expect(announcements, contains('New message: Persistent semantics'));
    });
  });

  group('NotificationPopup', () {
    testWidgets('uses custom icon background color', (tester) async {
      const customColor = Color(0xFF336699);

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationPopup(
            icon: TotemIcons.chat,
            title: 'Custom color',
            message: 'Uses overridden icon color',
            iconBackgroundColor: customColor,
          ),
        ),
      );

      final iconBackground = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.shape == BoxShape.circle &&
            decoration.color == customColor;
      });

      expect(iconBackground, findsOneWidget);
    });

    testWidgets('handles long title and message without layout exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: NotificationPopup(
                icon: TotemIcons.chat,
                title: 'Very long popup title that must remain stable in UI',
                message:
                    'Very long popup message that should be truncated safely '
                    'without causing overflow exceptions during layout.',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
