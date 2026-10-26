import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('fires waiting décor on mount', (tester) async {
    final received = <BoxDecoration>[];
    RoomBackground.onBackgroundChanged = received.add;
    addTearDown(() => RoomBackground.onBackgroundChanged = null);

    await tester.pumpWidget(
      host(const RoomBackground(child: SizedBox.shrink())),
    );

    check(received).deepEquals([RoomBackground.waitingDecoration]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('fires room décor when status changes', (tester) async {
    final received = <BoxDecoration>[];
    RoomBackground.onBackgroundChanged = received.add;
    addTearDown(() => RoomBackground.onBackgroundChanged = null);

    await tester.pumpWidget(
      host(
        const RoomBackground(
          status: RoomStatus.waitingRoom,
          child: SizedBox.shrink(),
        ),
      ),
    );
    check(received).deepEquals([RoomBackground.waitingDecoration]);

    await tester.pumpWidget(
      host(
        const RoomBackground(
          status: RoomStatus.active,
          child: SizedBox.shrink(),
        ),
      ),
    );
    check(received).deepEquals([
      RoomBackground.waitingDecoration,
      RoomBackground.roomDecoration,
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'does not fire waiting décor after unmount in the same frame',
    (tester) async {
      final received = <BoxDecoration>[];
      RoomBackground.onBackgroundChanged = received.add;
      addTearDown(() => RoomBackground.onBackgroundChanged = null);

      // Attach without pumping so initState can schedule its post-frame
      // notify, then replace the tree before that callback runs. Use the
      // same View wrapper as pumpWidget so leak tracking can unmount it.
      // The mounted guard must drop the waiting décor; dispose may still
      // restore cream synchronously.
      tester.binding.attachRootWidget(
        tester.binding.wrapWithDefaultView(
          host(const RoomBackground(child: SizedBox.shrink())),
        ),
      );
      tester.binding.attachRootWidget(
        tester.binding.wrapWithDefaultView(const SizedBox.shrink()),
      );
      await tester.pump();

      // Waiting/room décor must not be delivered after unmount. Dispose
      // may still restore the default cream page chrome.
      check(received.contains(RoomBackground.waitingDecoration)).isFalse();
      check(received.contains(RoomBackground.roomDecoration)).isFalse();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
