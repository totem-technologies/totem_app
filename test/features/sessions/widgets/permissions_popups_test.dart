// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_method_channel.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platform/platform.dart';
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
  Future<PermissionsState> build() async {
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
    final current = state.asData?.value ?? const PermissionsState();
    state = AsyncData(
      current.copyWith(notificationStatus: PermissionStatus.granted),
    );
  }

  @override
  Future<void> requestMicrophone() async {
    microphoneRequests++;
    final current = state.asData?.value ?? const PermissionsState();
    state = AsyncData(
      current.copyWith(microphoneStatus: PermissionStatus.granted),
    );
  }

  @override
  Future<void> requestCamera() async {
    cameraRequests++;
    final current = state.asData?.value ?? const PermissionsState();
    state = AsyncData(
      current.copyWith(cameraStatus: PermissionStatus.granted),
    );
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
      await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
    testWidgets('returns true without showing sheet when already granted', (
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

      final result = await showPermissionsRequestSheet(context);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(PermissionsRequestSheet), findsNothing);
    });

    testWidgets('returns false when dismissed', (tester) async {
      FakePermissionsController.initialState = const PermissionsState(
        cameraStatus: PermissionStatus.denied,
        microphoneStatus: PermissionStatus.denied,
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

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await future, isFalse);
    });

    testWidgets('returns true when tapping Continue in ready state', (
      tester,
    ) async {
      FakePermissionsController.initialState = const PermissionsState();

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

      await tester.tap(find.text('Mic'));
      await tester.tap(find.text('Camera'));
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(await future, isTrue);
    });
  });

  group('BackgroundActivityDialog', () {
    const methodChannel = MethodChannel('flutter_foreground_task/methods');

    setUp(() {
      final platform = FlutterForegroundTaskPlatform.instance;
      if (platform is MethodChannelFlutterForegroundTask) {
        platform.platform = FakePlatform(operatingSystem: 'android');
      }
    });

    tearDown(() {
      final platform = FlutterForegroundTaskPlatform.instance;
      if (platform is MethodChannelFlutterForegroundTask) {
        platform.platform = const LocalPlatform();
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    testWidgets('is skipped when battery optimization is already ignored', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            if (call.method == 'isIgnoringBatteryOptimizations') {
              return true;
            }
            if (call.method == 'requestIgnoreBatteryOptimization') {
              return true;
            }
            return null;
          });

      final context = await pumpHost(tester, child: const SizedBox.shrink());

      await showBackgroundActivityDialog(context);
      await tester.pumpAndSettle();

      expect(find.text('Stay connected'), findsNothing);
    });

    testWidgets('is not dismissed by tapping outside dialog', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            if (call.method == 'isIgnoringBatteryOptimizations') {
              return false;
            }
            if (call.method == 'requestIgnoreBatteryOptimization') {
              return true;
            }
            return null;
          });

      final context = await pumpHost(tester, child: const SizedBox.shrink());

      unawaited(showBackgroundActivityDialog(context));
      await tester.pumpAndSettle();

      expect(find.text('Stay connected'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Stay connected'), findsOneWidget);
    });

    testWidgets('closes when tapping Enable Background Mode', (tester) async {
      var requestCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            if (call.method == 'isIgnoringBatteryOptimizations') {
              return false;
            }
            if (call.method == 'requestIgnoreBatteryOptimization') {
              requestCalled = true;
              return true;
            }
            return null;
          });

      final context = await pumpHost(tester, child: const SizedBox.shrink());

      unawaited(showBackgroundActivityDialog(context));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Background Mode'));
      await tester.pumpAndSettle();

      expect(requestCalled, isTrue);
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
