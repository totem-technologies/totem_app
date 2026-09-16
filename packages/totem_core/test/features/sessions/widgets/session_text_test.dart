import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/session_text.dart';

import '../controllers/core/session_controller_mock.dart';

class _MockRoom extends Mock implements Room {}

void main() {
  testWidgets('share timer does not change the session label line height', (
    tester,
  ) async {
    final session = MockSessionController();
    final room = _MockRoom();
    when(() => session.session).thenReturn(null);
    when(() => session.room).thenReturn(room);
    when(() => room.name).thenReturn('Session name');

    Future<double> pumpTitle(DateTime? shareTimeStartedAt) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWithValue(session),
            sessionMessagingControllerProvider(
              session,
            ).overrideWithValue(shareTimeStartedAt),
          ],
          child: const MaterialApp(home: Scaffold(body: SessionTitle())),
        ),
      );
      await tester.pump();

      final sessionLabel = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().startsWith('SESSION'),
      );
      return tester.getSize(sessionLabel).height;
    }

    final heightWithoutTimer = await pumpTitle(null);
    final heightWithTimer = await pumpTitle(
      DateTime.now().subtract(const Duration(minutes: 2)),
    );

    check(heightWithTimer).equals(heightWithoutTimer);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
