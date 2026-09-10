import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_mic_button.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';

import '../../livekit_mocks.dart';

void main() {
  testWidgets('ActionBarMicButton calls onToggle with enabled=true when off', (
    tester,
  ) async {
    bool? requested;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarMicButton(
            participant: null,
            onToggle: (shouldEnable) async {
              requested = shouldEnable;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionBarButton));
    await tester.pump();

    expect(requested, isTrue);
  });

  testWidgets('ActionBarMicButton ignores re-entry while busy', (tester) async {
    var callCount = 0;
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarMicButton(
            participant: null,
            onToggle: (_) {
              callCount++;
              return completer.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionBarButton));
    await tester.pump();
    await tester.tap(find.byType(ActionBarButton));
    await tester.pump();

    expect(callCount, 1);

    completer.complete();
    await tester.pumpAndSettle();
  });

  group('live mic indicator color', () {
    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('livekit_client'), (
            call,
          ) async {
            return call.method == 'startVisualizer' ? true : null;
          });
    });

    MockLocalAudioTrack liveTrack() {
      final audioTrack = MockLocalAudioTrack();
      final mediaStreamTrack = MockMediaStreamTrack();
      when(() => audioTrack.mediaStreamTrack).thenReturn(mediaStreamTrack);
      when(() => mediaStreamTrack.id).thenReturn('local-track-1');
      when(audioTrack.createListener).thenReturn(MockTrackEventsListener());
      return audioTrack;
    }

    Future<Color?> pumpIndicatorColor(
      WidgetTester tester, {
      required Color surfaceTextColor,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle.merge(
              style: TextStyle(color: surfaceTextColor),
              child: ActionBar(
                children: [
                  ActionBarMicButton(
                    participant: null,
                    audioTrack: liveTrack(),
                    onToggle: (_) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      return tester
          .widget<SpeakingIndicatorAudioTrack>(
            find.byType(SpeakingIndicatorAudioTrack),
          )
          .foregroundColor;
    }

    testWidgets('is cream on the in-call slate bar, not the app deepGray', (
      tester,
    ) async {
      // Regression: reading IconTheme above ActionBarButton returned the
      // app-wide deepGray, which disappeared against the dark in-call pill.
      final color = await pumpIndicatorColor(
        tester,
        surfaceTextColor: Colors.white,
      );

      expect(color, AppTheme.cream);
    });

    testWidgets('is slate on the waiting-room cream bar', (tester) async {
      final color = await pumpIndicatorColor(
        tester,
        surfaceTextColor: Colors.black,
      );

      expect(color, AppTheme.slate);
    });
  });
}
