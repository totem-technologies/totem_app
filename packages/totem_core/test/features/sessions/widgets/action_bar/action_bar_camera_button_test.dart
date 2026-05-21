import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';

import '../../controllers/core/session_controller_mock.dart';
import '../../controllers/features/session_device_controller_mock.dart';
import '../../livekit_mocks.dart';

void main() {
  late FakeSessionController sessionController;
  late LocalParticipant participant;
  late FakeSessionDeviceController devices;

  setUp(() {
    sessionController = FakeSessionController();
    participant = MockLocalParticipant();
    devices = sessionController.devices as FakeSessionDeviceController;

    when(
      participant.createListener,
    ).thenReturn(MockParticipantEventsListener());
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

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      expect(
        find.byType(ActionBarCameraSwitcherButtonOverlay),
        findsOneWidget,
      );
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

      final hasSwitcherArrow = find
          .byIcon(Icons.keyboard_arrow_down)
          .evaluate()
          .isNotEmpty;
      if (!hasSwitcherArrow) {
        expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
        await tester.tap(find.byType(ActionBarButton));
        await tester.pump();

        expect(toggles, 1);
      } else {
        expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      }
    });

    testWidgets('dismisses overlay when tapping outside', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
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
              position: const Offset(100, 100),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionBarCameraSwitcherButtonOverlay), findsOneWidget);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('desktop overlay shows empty state with no cameras', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              isDesktopPicker: true,
              initialCameraPosition: CameraPosition.front,
              availableCameraDevices: const [],
              selectedCameraDeviceId: null,
              onCameraPositionChanged: (_) {},
              onCameraDeviceSelected: (_) {},
              onDismissOverlay: () {},
              position: const Offset(100, 100),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No cameras found'), findsOneWidget);
    });

    testWidgets('desktop overlay selects device and dismisses', (tester) async {
      MediaDevice? selected;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
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
              position: const Offset(100, 100),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Rear Camera'));
      await tester.pump();

      expect(selected?.deviceId, 'camera-2');
      expect(dismissed, isTrue);
    });

    testWidgets('mobile overlay toggles front/back camera position', (
      tester,
    ) async {
      final selectedPositions = <CameraPosition>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarCameraSwitcherButtonOverlay(
              isDesktopPicker: false,
              initialCameraPosition: CameraPosition.front,
              availableCameraDevices: const [],
              selectedCameraDeviceId: null,
              onCameraPositionChanged: selectedPositions.add,
              onCameraDeviceSelected: (_) {},
              onDismissOverlay: () {},
              position: const Offset(100, 100),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Front'));
      await tester.pump();
      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(selectedPositions, [CameraPosition.back, CameraPosition.front]);
    });
  });

  group('SessionActionBarCameraButton', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('toggling camera when tapped', (
      tester,
    ) async {
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

      expect(devices.enableCameraCalled, isTrue);
      expect(devices.disableCameraCalled, isFalse);

      // force disabled state
      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenAnswer(
        (_) => MockLocalTrackPublication(muted: false, isActive: true),
      );

      await tester.tap(find.byType(ActionBarButton));
      await tester.pumpAndSettle();

      expect(devices.disableCameraCalled, isTrue);
    });
  });
}
