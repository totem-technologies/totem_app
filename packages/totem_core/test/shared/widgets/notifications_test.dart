// ignore_for_file: cascade_invocations

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    final hostKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(key: hostKey)),
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
      check(tester.widgetList(find.text('Auto dismiss'))).length.equals(1);

      await tester.pump(const Duration(milliseconds: 400));
      check(tester.widgetList(find.text('Auto dismiss'))).length.equals(1);

      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Auto dismiss'))).length.equals(0);
    });

    testWidgets('show with zero duration stays until manually dismissed', (
      tester,
    ) async {
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
      check(tester.widgetList(find.text('No timer'))).length.equals(1);

      await tester.pump(const Duration(seconds: 10));
      check(tester.widgetList(find.text('No timer'))).length.equals(1);

      dismiss.dismissActive();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('No timer'))).length.equals(0);
    });

    testWidgets('show respects short duration and animation boundaries', (
      tester,
    ) async {
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
      check(tester.widgetList(find.text('Timing check'))).length.equals(1);

      await tester.pump(const Duration(milliseconds: 100));
      check(tester.widgetList(find.text('Timing check'))).length.equals(1);

      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Timing check'))).length.equals(0);
    });
  });

  group('NotificationController.showDismissible', () {
    testWidgets('showDismissible stays visible until dismiss callback', (
      tester,
    ) async {
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
      check(tester.widgetList(find.text('Dismissible'))).length.equals(1);

      await tester.pump(const Duration(seconds: 8));
      check(tester.widgetList(find.text('Dismissible'))).length.equals(1);

      dismiss.dismissActive();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Dismissible'))).length.equals(0);
    });
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
      check(tester.widgetList(find.text('Auto dismiss'))).length.equals(1);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Auto dismiss'))).length.equals(0);
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
      check(tester.widgetList(find.text('Permanent'))).length.equals(1);

      await tester.pump(const Duration(seconds: 10));
      check(tester.widgetList(find.text('Permanent'))).length.equals(1);

      dismiss.dismissActive();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Permanent'))).length.equals(0);
    });

    testWidgets('showPermanent can be dismissed immediately after show', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      final dismiss = controller.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Early dismiss',
        message: 'Should close quickly',
      );

      await tester.pump();
      check(tester.widgetList(find.text('Early dismiss'))).length.equals(1);

      dismiss.dismissActive();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Early dismiss'))).length.equals(0);
    });

    testWidgets('showPermanent dismiss callback is idempotent', (tester) async {
      final context = await pumpHost(tester);
      final controller = NotificationController();

      final dismiss = controller.showPermanent(
        context,
        icon: TotemIcons.pause,
        title: 'Idempotent',
        message: 'Dismiss can be called multiple times',
      );

      await tester.pump();
      check(tester.widgetList(find.text('Idempotent'))).length.equals(1);

      dismiss.dismissActive();
      dismiss.dismissActive();
      controller.dismissAll();
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Idempotent'))).length.equals(0);
    });

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
        check(tester.widgetList(find.text('Permanent A'))).length.equals(1);
        check(tester.widgetList(find.text('Permanent B'))).length.equals(0);

        controller.dismissAll();
        await tester.pumpAndSettle();

        check(tester.widgetList(find.text('Permanent A'))).length.equals(0);
        check(tester.widgetList(find.text('Permanent B'))).length.equals(0);
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
      check(tester.widgetList(find.text('Duplicate'))).length.equals(1);

      controller.dismissAll();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Duplicate'))).length.equals(0);
    });

    testWidgets(
      'duplicate requested during dismissal is shown after it closes',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        final first = controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Flaky connection',
          message: 'Connection dropped',
        );
        final duplicate = controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Flaky connection',
          message: 'Connection dropped',
        );

        check(identical(duplicate, first)).equals(true);
        await tester.pump();

        first.dismissActive();
        await tester.pump(const Duration(milliseconds: 100));

        final replacement = controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Flaky connection',
          message: 'Connection dropped',
        );

        check(identical(replacement, first)).equals(false);
        await tester.pumpAndSettle();
        check(
          tester.widgetList(find.text('Flaky connection')),
        ).length.equals(1);

        replacement.dismissActive();
        await tester.pumpAndSettle();
        check(
          tester.widgetList(find.text('Flaky connection')),
        ).length.equals(0);
      },
    );
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
      check(tester.widgetList(find.text('Ephemeral'))).length.equals(1);
      check(tester.widgetList(find.text('Persistent'))).length.equals(0);

      controller.dismissAll();
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Ephemeral'))).length.equals(0);
      check(tester.widgetList(find.text('Persistent'))).length.equals(0);
    });

    testWidgets('dismissAll on empty controller is a no-op', (tester) async {
      final controller = NotificationController();
      controller.dismissAll();
      await tester.pump();
      check(tester.takeException()).isNull();
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
      check(tester.widgetList(find.text('Controller A'))).length.equals(1);
      check(tester.widgetList(find.text('Controller B'))).length.equals(1);

      controllerA.dismissAll();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Controller A'))).length.equals(0);
      check(tester.widgetList(find.text('Controller B'))).length.equals(1);

      controllerB.dismissAll();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Controller B'))).length.equals(0);
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
        check(tester.widgetList(find.text('Auto unregister'))).length.equals(1);

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        check(tester.widgetList(find.text('Auto unregister'))).length.equals(0);

        controller.dismissAll();
        await tester.pump();
        check(tester.takeException()).isNull();
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
      check(tester.widgetList(find.text('Ephemeral mixed'))).length.equals(1);
      check(tester.widgetList(find.text('Permanent mixed'))).length.equals(0);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Ephemeral mixed'))).length.equals(0);
      check(tester.widgetList(find.text('Permanent mixed'))).length.equals(1);

      controller.dismissAll();
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Permanent mixed'))).length.equals(0);
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
      check(tester.widgetList(find.text('Race safe'))).length.equals(1);

      dismiss.dismissActive();
      controller.dismissAll();
      dismiss.dismissActive();
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Race safe'))).length.equals(0);
      check(tester.takeException()).isNull();
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
      check(tester.widgetList(find.text('Never built'))).length.equals(0);
    });

    testWidgets(
      'dismissImmediately removes a mounted banner without animating',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        final request = controller.showPermanent(
          context,
          icon: TotemIcons.chat,
          title: 'Remove now',
          message: 'Must not overlap the next screen',
        );
        await tester.pump();
        check(tester.widgetList(find.text('Remove now'))).length.equals(1);

        request.dismissImmediately();
        await tester.pump();

        check(tester.widgetList(find.text('Remove now'))).length.equals(0);
      },
    );

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
      check(tester.widgetList(find.text('Hidden timed'))).length.equals(0);
    });

    testWidgets(
      'showPermanent while hidden is still visible when the app returns',
      (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
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
        check(
          tester.widgetList(find.text('Hidden permanent')),
        ).length.equals(1);

        controller.dismissAll();
        await tester.pumpAndSettle();
        check(
          tester.widgetList(find.text('Hidden permanent')),
        ).length.equals(0);
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
      check(announcements).contains('New message: Ephemeral semantics');
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
      check(announcements).contains('New message: Persistent semantics');
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

      check(tester.widgetList(iconBackground)).length.equals(1);
    });

    group('NotificationController.blocked', () {
      testWidgets('rejects new notifications when blocked', (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        controller.blocked = true;
        check(controller.blocked).equals(true);

        controller.showTimed(
          context,
          icon: TotemIcons.chat,
          title: 'Blocked',
          message: 'Should not appear',
        );

        await tester.pump();
        check(tester.widgetList(find.text('Blocked'))).length.equals(0);
      });

      testWidgets('dismisses active notifications when becoming blocked', (
        tester,
      ) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        controller.showPermanent(
          context,
          icon: TotemIcons.pause,
          title: 'Active',
          message: 'Should be dismissed',
        );

        await tester.pump();
        check(tester.widgetList(find.text('Active'))).length.equals(1);

        controller.blocked = true;
        await tester.pumpAndSettle();
        check(tester.widgetList(find.text('Active'))).length.equals(0);
      });

      testWidgets('allows notifications after unblocking', (tester) async {
        final context = await pumpHost(tester);
        final controller = NotificationController();

        controller.blocked = true;

        controller.showTimed(
          context,
          icon: TotemIcons.chat,
          title: 'Blocked',
          message: 'Should not appear',
        );
        await tester.pump();
        check(tester.widgetList(find.text('Blocked'))).length.equals(0);

        controller.blocked = false;
        check(controller.blocked).equals(false);

        controller.showTimed(
          context,
          icon: TotemIcons.chat,
          title: 'Unblocked',
          message: 'Should appear',
        );
        await tester.pump();
        check(tester.widgetList(find.text('Unblocked'))).length.equals(1);
      });

      testWidgets('idempotent block/unblock', (tester) async {
        final controller = NotificationController();

        controller.blocked = true;
        check(controller.blocked).equals(true);
        controller.blocked = true; // no-op
        check(controller.blocked).equals(true);

        controller.blocked = false;
        check(controller.blocked).equals(false);
        controller.blocked = false; // no-op
        check(controller.blocked).equals(false);

        await tester.pump();
        check(tester.takeException()).isNull();
      });
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
      check(tester.takeException()).isNull();
    });
  });
}
