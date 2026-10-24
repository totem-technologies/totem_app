import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_preview_card.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../livekit_mocks.dart';

void main() {
  late VoidCallback restoreWebRtcChannels;

  setUpAll(() {
    restoreWebRtcChannels = stubFlutterWebRtcChannels();
  });

  tearDownAll(() {
    restoreWebRtcChannels();
  });

  Future<void> pumpPreview(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  group('LocalParticipantCard', () {
    testWidgets('keeps a local renderer mounted while the camera is covered', (
      tester,
    ) async {
      final cameraOn = ValueNotifier(true);
      final track = MockLocalVideoTrack();
      when(() => track.sid).thenReturn('local-track');
      addTearDown(cameraOn.dispose);

      await pumpPreview(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: cameraOn,
          builder: (_, isCameraOn, _) =>
              LocalParticipantCard(isCameraOn: isCameraOn, videoTrack: track),
        ),
      );
      await tester.pumpAndSettle();
      final renderer = tester.element(find.byType(VideoTrackRenderer));

      cameraOn.value = false;
      await tester.pump();

      check(
        tester.element(find.byType(VideoTrackRenderer)),
      ).identicalTo(renderer);
      check(tester.widgetList(find.byType(UserAvatar))).length.equals(2);

      cameraOn.value = true;
      await tester.pump();

      check(
        tester.element(find.byType(VideoTrackRenderer)),
      ).identicalTo(renderer);
      check(tester.widgetList(find.byType(UserAvatar))).length.equals(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
