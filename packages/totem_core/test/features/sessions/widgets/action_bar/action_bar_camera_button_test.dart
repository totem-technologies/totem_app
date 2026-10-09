import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/media_devices_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_core/shared/totem_icons.dart';

import '../../controllers/core/session_controller_mock.dart';
import '../../media/fake_local_media.dart';

Finder _cameraCaret() {
  return find.byWidgetPredicate(
    (widget) => widget is TotemIcon && widget.icon == TotemIcons.chevronDown,
  );
}

void main() {
  late FakeSessionController sessionController;

  setUp(() {
    sessionController = FakeSessionController();
  });

  group('ActionBarCameraSwitcherButton', () {
    testWidgets('shows adaptive camera options overlay', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              // Keeps the switcher at the bottom so the overlay lays out
              // above the button the same way it does in session.
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: ActionBarCameraSwitcherButton(
                  isCameraOn: true,
                  onToggle: () {},
                  cameraFacing: CameraFacing.front,
                  availableCameraDevices: [
                    fakeCamera('camera-1', 'Front Camera'),
                    fakeCamera('camera-2', 'Rear Camera'),
                  ],
                  selectedCameraDeviceId: 'camera-2',
                  onCameraFacingChanged: (_) {},
                  onCameraDeviceSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Choose camera'));
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(ActionBarCameraSwitcherButtonOverlay)),
      ).length.equals(1);
    });

    testWidgets('positions overlay from button across render subtrees', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                const Expanded(child: SizedBox()),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 120),
                    ActionBarCameraSwitcherButton(
                      isCameraOn: true,
                      onToggle: () {},
                      cameraFacing: CameraFacing.front,
                      availableCameraDevices: [
                        fakeCamera('camera-1', 'Front Camera'),
                        fakeCamera('camera-2', 'Rear Camera'),
                      ],
                      selectedCameraDeviceId: 'camera-1',
                      onCameraFacingChanged: (_) {},
                      onCameraDeviceSelected: (_) {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Choose camera'));
      await tester.pumpAndSettle();

      final button = tester.getTopLeft(
        find.byKey(ActionBarCameraSwitcherButton.deviceClusterKey),
      );
      final menu = tester.getTopLeft(find.text('Front Camera'));

      check(menu.dx).isGreaterThan(0);
      check(menu.dy).isLessThan(button.dy);
    });

    testWidgets('device caret is labeled as camera selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButton(
              isCameraOn: true,
              onToggle: () {},
              cameraFacing: CameraFacing.front,
              availableCameraDevices: [
                fakeCamera('camera-1', 'Front Camera'),
                fakeCamera('camera-2', 'Rear Camera'),
              ],
              selectedCameraDeviceId: 'camera-2',
              onCameraFacingChanged: (_) {},
              onCameraDeviceSelected: (_) {},
            ),
          ),
        ),
      );

      check(
        tester.widgetList(find.bySemanticsLabel('Choose camera')),
      ).length.equals(1);
      final caret = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Choose camera',
        ),
      );
      check(caret.properties.hint).equals('Opens camera selection');
    });

    testWidgets('caret is grouped on the trailing side of the camera', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButton(
              isCameraOn: true,
              onToggle: () {},
              cameraFacing: CameraFacing.front,
              availableCameraDevices: [
                fakeCamera('camera-1', 'Front Camera'),
                fakeCamera('camera-2', 'Rear Camera'),
              ],
              selectedCameraDeviceId: 'camera-2',
              onCameraFacingChanged: (_) {},
              onCameraDeviceSelected: (_) {},
            ),
          ),
        ),
      );

      final cluster = find.byKey(
        ActionBarCameraSwitcherButton.deviceClusterKey,
      );
      final camera = find.descendant(
        of: cluster,
        matching: find.byType(ActionBarButton),
      );
      final caret = find.descendant(of: cluster, matching: _cameraCaret());

      check(tester.widgetList(cluster)).length.equals(1);
      check(tester.widgetList(camera)).length.equals(1);
      check(tester.widgetList(caret)).length.equals(1);
      check(
        tester.getCenter(caret).dx,
      ).isGreaterThan(tester.getCenter(camera).dx);
    });

    testWidgets('mobile web shows front/back camera options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButton(
              isCameraOn: true,
              onToggle: () {},
              cameraFacing: CameraFacing.front,
              availableCameraDevices: [
                fakeCamera('camera-1', 'Front Camera'),
                fakeCamera('camera-2', 'Rear Camera'),
              ],
              selectedCameraDeviceId: 'camera-1',
              onCameraFacingChanged: (_) {},
              onCameraDeviceSelected: (_) {},
            ),
          ),
        ),
      );

      check(
        tester.widgetList(
          find.byKey(ActionBarCameraSwitcherButton.deviceClusterKey),
        ),
      ).length.equals(1);
      await tester.tap(find.bySemanticsLabel('Switch camera'));
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Front'))).length.equals(1);
      check(tester.widgetList(find.text('Back'))).length.equals(1);
      check(tester.widgetList(find.text('Front Camera'))).length.equals(0);
    }, skip: !kIsWeb);

    testWidgets('one-camera mode is platform-adaptive', (tester) async {
      var toggles = 0;

      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              // Keeps the switcher at the bottom so the overlay lays out
              // above the button the same way it does in session.
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: ActionBarCameraSwitcherButton(
                  isCameraOn: true,
                  onToggle: () {
                    toggles++;
                  },
                  cameraFacing: CameraFacing.front,
                  availableCameraDevices: [
                    fakeCamera('camera-1', 'Front Camera'),
                  ],
                  selectedCameraDeviceId: 'camera-1',
                  onCameraFacingChanged: (_) {},
                  onCameraDeviceSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hasSwitcherArrow = _cameraCaret().evaluate().isNotEmpty;
      if (!hasSwitcherArrow) {
        check(tester.widgetList(_cameraCaret())).length.equals(0);
        check(
          tester.widgetList(
            find.byKey(ActionBarCameraSwitcherButton.deviceClusterKey),
          ),
        ).length.equals(0);
        await tester.tap(find.byType(ActionBarButton));
        await tester.pump();

        check(toggles).equals(1);
      } else {
        check(tester.widgetList(_cameraCaret())).length.equals(1);
      }
    });

    testWidgets('dismisses overlay when tapping outside', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              buttonKey: GlobalKey(),
              isDesktopPicker: true,
              initialCameraFacing: CameraFacing.front,
              availableCameraDevices: [fakeCamera('camera-1', 'Front Camera')],
              selectedCameraDeviceId: 'camera-1',
              onCameraFacingChanged: (_) {},
              onCameraDeviceSelected: (_) {},
              onDismissOverlay: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(ActionBarCameraSwitcherButtonOverlay)),
      ).length.equals(1);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      check(dismissed).equals(true);
    });

    testWidgets('desktop overlay shows empty state with no cameras', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              buttonKey: GlobalKey(),
              isDesktopPicker: true,
              initialCameraFacing: CameraFacing.front,
              availableCameraDevices: const [],
              selectedCameraDeviceId: null,
              onCameraFacingChanged: (_) {},
              onCameraDeviceSelected: (_) {},
              onDismissOverlay: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('No cameras found'))).length.equals(1);
    });

    testWidgets('desktop overlay selects device and dismisses', (tester) async {
      MediaDeviceInfo? selected;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              buttonKey: GlobalKey(),
              isDesktopPicker: true,
              initialCameraFacing: CameraFacing.front,
              availableCameraDevices: [
                fakeCamera('camera-1', 'Front Camera'),
                fakeCamera('camera-2', 'Rear Camera'),
              ],
              selectedCameraDeviceId: 'camera-1',
              onCameraFacingChanged: (_) {},
              onCameraDeviceSelected: (device) {
                selected = device;
              },
              onDismissOverlay: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Rear Camera'));
      await tester.pump();

      check(selected?.id).equals('camera-2');
      check(dismissed).equals(true);
    });

    testWidgets('mobile overlay toggles front/back camera position', (
      tester,
    ) async {
      final selectedPositions = <CameraFacing>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              buttonKey: GlobalKey(),
              isDesktopPicker: false,
              initialCameraFacing: CameraFacing.front,
              availableCameraDevices: const [],
              selectedCameraDeviceId: null,
              onCameraFacingChanged: selectedPositions.add,
              onCameraDeviceSelected: (_) {},
              onDismissOverlay: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Front'));
      await tester.pump();
      await tester.tap(find.text('Back'));
      await tester.pump();

      check(
        selectedPositions,
      ).deepEquals([CameraFacing.back, CameraFacing.front]);
    });
  });

  group('SessionActionBarCameraButton', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    Future<void> pumpCameraButton(WidgetTester tester) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaDeviceCatalogProvider.overrideWithValue(
              FakeMediaDeviceCatalog(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SessionActionBarCameraButton(session: sessionController),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the join preference before the camera is published', (
      tester,
    ) async {
      sessionController.mockOptions = const SessionOptions(
        sessionSlug: 'test-session',
        token: 'test-token',
        cameraEnabled: true,
        microphoneEnabled: false,
        speakerEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
      );

      await pumpCameraButton(tester);

      check(
        tester.widgetList(find.bySemanticsLabel('Camera on')),
      ).length.equals(1);
    });

    testWidgets('toggles the camera on and off', (tester) async {
      final media = sessionController.mockLocalMedia;
      await pumpCameraButton(tester);

      await tester.tap(find.byType(ActionBarButton));
      await tester.pumpAndSettle();

      check(media.cameraCommands).deepEquals([true]);
      check(
        tester.widgetList(find.bySemanticsLabel('Camera on')),
      ).length.equals(1);

      await tester.tap(find.byType(ActionBarButton));
      await tester.pumpAndSettle();

      check(media.cameraCommands).deepEquals([true, false]);
      check(
        tester.widgetList(find.bySemanticsLabel('Camera off')),
      ).length.equals(1);
    });

    testWidgets('web camera action ignores overlapping presses and recovers', (
      tester,
    ) async {
      final media = sessionController.mockLocalMedia;
      final pendingEnable = Completer<void>();
      media.onCameraCommand = (enabled) async {
        if (enabled) await pendingEnable.future;
      };

      await pumpCameraButton(tester);
      await tester.pump();

      check(
        tester.widgetList(find.byType(ActionBarCameraSwitcherButton)),
      ).length.equals(1);

      await tester.tap(find.byType(ActionBarButton));
      await tester.pump();
      await tester.tap(find.byType(ActionBarButton), warnIfMissed: false);
      await tester.pump();

      check(media.cameraCommands).deepEquals([true]);

      pendingEnable.complete();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(ActionBarButton));
      await tester.pump();

      check(media.cameraCommands).deepEquals([true, false]);
    }, skip: !kIsWeb);
  });
}
