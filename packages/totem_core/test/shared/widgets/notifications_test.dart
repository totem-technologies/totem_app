// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

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

  group('NotificationController.show', () {
    testWidgets('show auto dismisses after configured duration', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      controller.show(
        context,
        duration: const Duration(milliseconds: 500),
        animationDuration: const Duration(milliseconds: 120),
        builder: (_) {
          return const NotificationBanner(
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

    testWidgets(
      'show with zero duration stays until manually dismissed',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        final dismiss = controller.show(
          context,
          duration: Duration.zero,
          builder: (_) {
            return const NotificationBanner(
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

        dismiss.dismissActive();
        await tester.pumpAndSettle();
        expect(find.text('No timer'), findsNothing);
      },
    );

    testWidgets(
      'show respects short duration and animation boundaries',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        controller.show(
          context,
          duration: const Duration(milliseconds: 120),
          animationDuration: const Duration(milliseconds: 80),
          builder: (_) {
            return const NotificationBanner(
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
      },
    );
  });

  group('NotificationController.showDismissible', () {
    testWidgets(
      'showDismissible stays visible until dismiss callback',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        final dismiss = controller.showDismissible(
          context,
          builder: (_) {
            return const NotificationBanner(
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

        dismiss.dismissActive();
        await tester.pumpAndSettle();
        expect(find.text('Dismissible'), findsNothing);
      },
    );
  });

  group('NotificationController.showTimed', () {
    testWidgets('showTimed eventually auto dismisses', (tester) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      controller.showTimed(
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

  group('NotificationController.showPermanent', () {
    testWidgets('showPermanent stays until dismissed', (tester) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      final dismiss = controller.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Permanent',
        message: 'Will stay visible',
      );

      await tester.pump();
      expect(find.text('Permanent'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Permanent'), findsOneWidget);

      dismiss.dismissActive();
      await tester.pumpAndSettle();
      expect(find.text('Permanent'), findsNothing);
    });

    testWidgets(
      'showPermanent can be dismissed immediately after show',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        final dismiss = controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Early dismiss',
          message: 'Should close quickly',
        );

        await tester.pump();
        expect(find.text('Early dismiss'), findsOneWidget);

        dismiss.dismissActive();
        await tester.pumpAndSettle();
        expect(find.text('Early dismiss'), findsNothing);
      },
    );

    testWidgets(
      'showPermanent dismiss callback is idempotent',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        final dismiss = controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Idempotent',
          message: 'Dismiss can be called multiple times',
        );

        await tester.pump();
        expect(find.text('Idempotent'), findsOneWidget);

        dismiss.dismissActive();
        dismiss.dismissActive();
        controller.dismissAll();
        await tester.pumpAndSettle();

        expect(find.text('Idempotent'), findsNothing);
      },
    );

    testWidgets(
      'NotificationController queues permanent notifications one after another',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Permanent A',
          message: 'First persistent notification',
        );

        controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Permanent B',
          message: 'Second persistent notification',
        );

        await tester.pump();
        expect(find.text('Permanent A'), findsOneWidget);
        expect(find.text('Permanent B'), findsNothing);

        controller.dismissAll();
        await tester.pumpAndSettle();

        expect(find.text('Permanent A'), findsNothing);
        expect(find.text('Permanent B'), findsNothing);
      },
    );

    testWidgets('duplicate notification is suppressed', (tester) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      controller.showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'Duplicate',
        message: 'Shown only once',
      );

      controller.showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'Duplicate',
        message: 'Shown only once',
      );

      await tester.pump();
      expect(find.text('Duplicate'), findsOneWidget);

      controller.dismissAll();
      await tester.pumpAndSettle();
      expect(find.text('Duplicate'), findsNothing);
    });
  });

  group('NotificationController', () {
    testWidgets('dismissAll closes active notifications', (tester) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      controller.showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'Ephemeral',
        message: 'Ephemeral message',
      );

      controller.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Persistent',
        message: 'Persistent message',
      );

      await tester.pump();
      expect(find.text('Ephemeral'), findsOneWidget);
      expect(find.text('Persistent'), findsNothing);

      controller.dismissAll();
      await tester.pumpAndSettle();

      expect(find.text('Ephemeral'), findsNothing);
      expect(find.text('Persistent'), findsNothing);
    });

    testWidgets('dismissAll on empty controller is a no-op', (tester) async {
      final controller = NotificationController();
      controller.dismissAll();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismissAll affects only its own controller notifications', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controllerA = NotificationController();
      final controllerB = NotificationController();

      controllerA.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Controller A',
        message: 'Owned by controller A',
      );

      controllerB.showPermanent(
        context,
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

    testWidgets(
      'auto-dismissed notification is safely unregistered from controller',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        controller.show(
          context,
          duration: const Duration(milliseconds: 150),
          animationDuration: const Duration(milliseconds: 80),
          builder: (_) {
            return const NotificationBanner(
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
      },
    );

    testWidgets('mixed auto and permanent lifecycle is handled correctly', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      controller.showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'Ephemeral mixed',
        message: 'Auto-dismisses',
      );

      controller.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Permanent mixed',
        message: 'Stays visible',
      );

      await tester.pump();
      expect(find.text('Ephemeral mixed'), findsOneWidget);
      expect(find.text('Permanent mixed'), findsNothing);

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
      final controller = NotificationController();

      final dismiss = controller.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Race safe',
        message: 'No double remove issues',
      );

      await tester.pump();
      expect(find.text('Race safe'), findsOneWidget);

      dismiss.dismissActive();
      controller.dismissAll();
      dismiss.dismissActive();
      await tester.pumpAndSettle();

      expect(find.text('Race safe'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('hidden app lifecycle', () {
    testWidgets('dismissActive removes a banner that was never built', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      final request = controller.showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'Never built',
        message: 'Dismissed before the first frame',
      );

      // No pump between show and dismiss: the overlay entry is inserted but
      // not built yet, like when the tab is hidden and no frames render.
      request.dismissActive();

      await tester.pump();
      expect(find.text('Never built'), findsNothing);
    });

    testWidgets('showTimed drops the banner while the app is hidden', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      try {
        controller.showTimed(
          context,
          icon: TotemIcons.chat,
          title: 'Hidden timed',
          message: 'Stale by the time the app is visible again',
        );
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }

      await tester.pump();
      expect(find.text('Hidden timed'), findsNothing);
    });

    testWidgets(
      'showPermanent while hidden is still visible when the app returns',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.hidden,
        );
        try {
          controller.showPermanent(
            context,
            icon: TotemIcons.pause,
            title: 'Hidden permanent',
            message: 'Should survive until the app is visible again',
          );
        } finally {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }

        await tester.pump();
        expect(find.text('Hidden permanent'), findsOneWidget);

        controller.dismissAll();
        await tester.pumpAndSettle();
        expect(find.text('Hidden permanent'), findsNothing);
      },
    );
  });

  group('semantics announcements', () {
    testWidgets('showTimed announces message', (tester) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();
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

      controller.showTimed(
        context,
        icon: TotemIcons.chat,
        title: 'Accessible',
        message: 'Ephemeral semantics',
      );

      await tester.pump();
      expect(announcements, contains('New message: Ephemeral semantics'));
    });

    testWidgets('showPermanent announces message', (tester) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();
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

      controller.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Accessible permanent',
        message: 'Persistent semantics',
      );

      await tester.pump();
      expect(announcements, contains('New message: Persistent semantics'));
    });
  });

  group('NotificationBanner', () {
    testWidgets('uses custom icon background color', (tester) async {
      const customColor = Color(0xFF336699);

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationBanner(
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
              child: NotificationBanner(
                icon: TotemIcons.chat,
                title:
                    'Very long notification title that must remain stable in UI',
                message:
                    'Very long notification message that should be truncated '
                    'safely without causing overflow exceptions during layout.',
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
