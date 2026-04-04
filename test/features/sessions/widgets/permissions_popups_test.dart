import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:totem_app/features/sessions/controllers/features/permissions_controller.dart';
import 'package:totem_app/features/sessions/widgets/permissions_popups.dart';

class FakePermissionsController extends PermissionsController {
  static PermissionsState initialState = const PermissionsState();
  static FakePermissionsController? lastInstance;

  int refreshCalls = 0;
  int notificationRequests = 0;
  int microphoneRequests = 0;
  int cameraRequests = 0;

  @override
  PermissionsState build() {
    lastInstance = this;
    return initialState;
  }

  @override
  Future<void> refreshStatuses() async {
    refreshCalls++;
  }

  @override
  Future<void> requestNotification() async {
    notificationRequests++;
  }

  @override
  Future<void> requestMicrophone() async {
    microphoneRequests++;
  }

  @override
  Future<void> requestCamera() async {
    cameraRequests++;
  }
}

void main() {
  Future<BuildContext> pumpHost(
    WidgetTester tester, {
    required Widget child,
    List<Object?> overrides = const [],
  }) async {
    final hostKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: hostKey),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );

    return hostKey.currentContext!;
  }

  setUp(() {
    FakePermissionsController.initialState = const PermissionsState();
    FakePermissionsController.lastInstance = null;
  });

  group('PermissionsRequestSheet', () {
    testWidgets('disables button when not ready', (
      tester,
    ) async {
      FakePermissionsController.initialState = const PermissionsState(
        cameraStatus: PermissionStatus.denied,
        microphoneStatus: PermissionStatus.denied,
        notificationStatus: PermissionStatus.denied,
      );

      await pumpHost(
        tester,
        child: const PermissionsRequestSheet(),
        overrides: [
          permissionsControllerProvider.overrideWith(
            FakePermissionsController.new,
          ),
        ],
      );

      expect(find.text('Grant Permissions'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'enables button when camera and mic granted',
      (
        tester,
      ) async {
        FakePermissionsController.initialState = const PermissionsState(
          cameraStatus: PermissionStatus.granted,
          microphoneStatus: PermissionStatus.granted,
          notificationStatus: PermissionStatus.denied,
        );

        await pumpHost(
          tester,
          child: const PermissionsRequestSheet(),
          overrides: [
            permissionsControllerProvider.overrideWith(
              FakePermissionsController.new,
            ),
          ],
        );

        expect(find.text('Continue'), findsOneWidget);

        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets('refreshes statuses on resumed lifecycle event', (
      tester,
    ) async {
      await pumpHost(
        tester,
        child: const PermissionsRequestSheet(),
        overrides: [
          permissionsControllerProvider.overrideWith(
            FakePermissionsController.new,
          ),
        ],
      );

      final controller = FakePermissionsController.lastInstance;
      expect(controller, isNotNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controller!.refreshCalls, 1);
    });

    testWidgets('tapping permission tiles triggers request methods', (
      tester,
    ) async {
      FakePermissionsController.initialState = const PermissionsState(
        cameraStatus: PermissionStatus.denied,
        microphoneStatus: PermissionStatus.denied,
        notificationStatus: PermissionStatus.denied,
      );

      await pumpHost(
        tester,
        child: const PermissionsRequestSheet(),
        overrides: [
          permissionsControllerProvider.overrideWith(
            FakePermissionsController.new,
          ),
        ],
      );

      final controller = FakePermissionsController.lastInstance;
      expect(controller, isNotNull);

      await tester.tap(find.text('Notification'));
      await tester.tap(find.text('Mic'));
      await tester.tap(find.text('Camera'));
      await tester.pump();

      expect(controller!.notificationRequests, 1);
      expect(controller.microphoneRequests, 1);
      expect(controller.cameraRequests, 1);
    });
  });

  group('showPermissionsRequestSheet', () {
    testWidgets('returns false when dismissed', (tester) async {
      final context = await pumpHost(
        tester,
        child: const SizedBox.shrink(),
        overrides: [
          permissionsControllerProvider.overrideWith(
            FakePermissionsController.new,
          ),
        ],
      );

      final future = showPermissionsRequestSheet(context);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await future, isFalse);
    });

    testWidgets('returns true when tapping Continue in ready state', (
      tester,
    ) async {
      FakePermissionsController.initialState = const PermissionsState(
        cameraStatus: PermissionStatus.granted,
        microphoneStatus: PermissionStatus.granted,
        notificationStatus: PermissionStatus.denied,
      );

      final context = await pumpHost(
        tester,
        child: const SizedBox.shrink(),
        overrides: [
          permissionsControllerProvider.overrideWith(
            FakePermissionsController.new,
          ),
        ],
      );

      final future = showPermissionsRequestSheet(context);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(await future, isTrue);
    });
  });

  group('BackgroundActivityDialog', () {
    testWidgets('is not dismissed by tapping outside dialog', (tester) async {
      final context = await pumpHost(tester, child: const SizedBox.shrink());

      unawaited(showBackgroundActivityDialog(context));
      await tester.pumpAndSettle();

      expect(find.text('Stay connected'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Stay connected'), findsOneWidget);
    });

    testWidgets('closes when tapping Enable Background Mode', (tester) async {
      final context = await pumpHost(tester, child: const SizedBox.shrink());

      unawaited(showBackgroundActivityDialog(context));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Background Mode'));
      await tester.pumpAndSettle();

      expect(find.text('Stay connected'), findsNothing);
    });
  });

  group('PermissionItemTile', () {
    testWidgets('invokes onTap when not granted', (tester) async {
      var taps = 0;

      await pumpHost(
        tester,
        child: PermissionItemTile(
          icon: const Icon(Icons.mic),
          title: 'Mic',
          description: 'Needs mic permission.',
          isGranted: false,
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.byType(PermissionItemTile));
      await tester.pump();

      expect(taps, 1);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('does not invoke onTap and shows check when granted', (
      tester,
    ) async {
      var taps = 0;

      await pumpHost(
        tester,
        child: PermissionItemTile(
          icon: const Icon(Icons.camera_alt),
          title: 'Camera',
          description: 'Needs camera permission.',
          isGranted: true,
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.byType(PermissionItemTile));
      await tester.pump();

      expect(taps, 0);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
