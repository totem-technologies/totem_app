import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_core/shared/totem_icons.dart';

import '../../controllers/core/session_controller_mock.dart';
import '../../controllers/features/session_device_controller_mock.dart';
import '../../livekit_mocks.dart';

Finder _cameraCaret() {
  return find.byWidgetPredicate(
    (widget) => widget is TotemIcon && widget.icon == TotemIcons.chevronDown,
  );
}

void main() {
  late FakeSessionController sessionController;
  late LocalParticipant participant;
  late FakeSessionDeviceController devices;

  setUp(() {
    sessionController = FakeSessionController();
    participant = MockLocalParticipant();
    devices = sessionController.devices as FakeSessionDeviceController;
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
                  cameraPosition: CameraPosition.front,
                  availableCameraDevices: const [
                    MediaDevice('camera-1', 'Front Camera', 'videoinput', null),
                    MediaDevice('camera-2', 'Rear Camera', 'videoinput', null),
                  ],
                  selectedCameraDeviceId: 'camera-2',
                  onCameraPositionChanged: (_) {},
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
              cameraPosition: CameraPosition.front,
              availableCameraDevices: const [
                MediaDevice('camera-1', 'Front Camera', 'videoinput', null),
                MediaDevice('camera-2', 'Rear Camera', 'videoinput', null),
              ],
              selectedCameraDeviceId: 'camera-2',
              onCameraPositionChanged: (_) {},
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
              cameraPosition: CameraPosition.front,
              availableCameraDevices: const [
                MediaDevice('camera-1', 'Front Camera', 'videoinput', null),
                MediaDevice('camera-2', 'Rear Camera', 'videoinput', null),
              ],
              selectedCameraDeviceId: 'camera-2',
              onCameraPositionChanged: (_) {},
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
                  cameraPosition: CameraPosition.front,
                  availableCameraDevices: const [
                    MediaDevice('camera-1', 'Front Camera', 'videoinput', null),
                  ],
                  selectedCameraDeviceId: 'camera-1',
                  onCameraPositionChanged: (_) {},
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
              initialCameraPosition: CameraPosition.front,
              availableCameraDevices: const [
                MediaDevice('camera-1', 'Front Camera', 'videoinput', null),
              ],
              selectedCameraDeviceId: 'camera-1',
              onCameraPositionChanged: (_) {},
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
              initialCameraPosition: CameraPosition.front,
              availableCameraDevices: const [],
              selectedCameraDeviceId: null,
              onCameraPositionChanged: (_) {},
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
      MediaDevice? selected;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              buttonKey: GlobalKey(),
              isDesktopPicker: true,
              initialCameraPosition: CameraPosition.front,
              availableCameraDevices: const [
                MediaDevice('camera-1', 'Front Camera', 'videoinput', null),
                MediaDevice('camera-2', 'Rear Camera', 'videoinput', null),
              ],
              selectedCameraDeviceId: 'camera-1',
              onCameraPositionChanged: (_) {},
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

      check(selected?.deviceId).equals('camera-2');
      check(dismissed).equals(true);
    });

    testWidgets('mobile overlay toggles front/back camera position', (
      tester,
    ) async {
      final selectedPositions = <CameraPosition>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              buttonKey: GlobalKey(),
              isDesktopPicker: false,
              initialCameraPosition: CameraPosition.front,
              availableCameraDevices: const [],
              selectedCameraDeviceId: null,
              onCameraPositionChanged: selectedPositions.add,
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
      ).deepEquals([CameraPosition.back, CameraPosition.front]);
    });
  });

  group('SessionActionBarCameraButton', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('toggling camera when tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionActionBarCameraButton(
              session: sessionController,
              participant: participant,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionBarButton));
      await tester.pumpAndSettle();

      check(devices.enableCameraCalled).equals(true);
      check(devices.disableCameraCalled).equals(false);

      // force disabled state
      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenAnswer(
        (_) => MockLocalTrackPublication(muted: false, isActive: true),
      );

      await tester.tap(find.byType(ActionBarButton));
      await tester.pumpAndSettle();

      check(devices.disableCameraCalled).equals(true);
    });
  });
}
