import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/room_media_providers.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_core/shared/totem_icons.dart';

import '../media/fake_room_media.dart';
import '../media/test_participants.dart';

void main() {
  final remoteParticipant = testParticipant('user-1', name: 'User 1');

  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    List<Object?> overrides = const [],
    FakeRoomMedia? roomMedia,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomMediaProvider.overrideWithValue(roomMedia ?? FakeRoomMedia()),
          ...overrides.cast(),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  /// Chrome a dense-grid tile resolves to, and what a large card caps at.
  final compactMetrics = ParticipantOverlayMetrics.forCard(
    const Size(160, 120),
  );

  group('SpeakingIndicator', () {
    testWidgets('shows the room media level for the participant', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        child: SpeakingIndicator(participant: remoteParticipant, barCount: 4),
      );

      final level = tester.widget<FakeMicrophoneLevel>(
        find.byType(FakeMicrophoneLevel),
      );
      check(level.participant).equals(remoteParticipant);
      check(level.barCount).equals(4);
    });

    testWidgets('shows the muted icon outside a session', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [roomMediaProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: Scaffold(
              body: SpeakingIndicator(participant: remoteParticipant),
            ),
          ),
        ),
      );

      final icon = tester.widget<TotemIcon>(find.byType(TotemIcon));
      check(icon.icon).equals(TotemIcons.microphoneOff);
    });
  });

  group('SpeakingIndicatorOrEmoji', () {
    testWidgets('renders the participant emoji instead of the indicator', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        overrides: [
          participantEmojisProvider(
            remoteParticipant.identity,
          ).overrideWith((ref) => ['🔥']),
        ],
        child: SpeakingIndicatorOrEmoji(
          participant: remoteParticipant,
          metrics: compactMetrics,
        ),
      );

      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('🔥'))).length.equals(1);
      check(
        tester.widgetList(find.byType(FakeMicrophoneLevel)),
      ).length.equals(0);
    });

    testWidgets('updates when the emoji provider changes', (tester) async {
      await pumpWidget(
        tester,
        child: SpeakingIndicatorOrEmoji(
          participant: remoteParticipant,
          metrics: compactMetrics,
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      final notifier = container.read(emojiReactionsProvider.notifier);

      check(
        tester.widgetList(find.byType(FakeMicrophoneLevel)),
      ).length.equals(1);
      check(tester.widgetList(find.text('🔥'))).length.equals(0);

      await notifier.emitIncomingReaction(remoteParticipant.identity, '🔥');
      await tester.pump();

      check(tester.widgetList(find.text('🔥'))).length.equals(1);
      check(
        tester.widgetList(find.byType(FakeMicrophoneLevel)),
      ).length.equals(0);

      notifier.clear();
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('🔥'))).length.equals(0);
      check(
        tester.widgetList(find.byType(FakeMicrophoneLevel)),
      ).length.equals(1);
    });
  });
}
