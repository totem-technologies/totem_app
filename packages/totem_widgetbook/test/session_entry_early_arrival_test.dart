import 'package:checks/checks.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_widgetbook/design/design.dart';

/// Early arrival keeps Join tappable. The tap explains when the room
/// opens — a sheet on the phone, a dialog once the frame is a window —
/// and does not enter the Session.
void main() {
  testWidgets('tapping Join before the window opens explains it on a phone', (
    tester,
  ) async {
    await _setSize(tester, const Size(360, 812));
    var joined = 0;

    await tester.pumpWidget(
      _host(phase: EntryPhase.tooEarly, onJoin: () => joined++),
    );
    await tester.pump();

    // The card is just facts and Join. The note waits for the tap.
    check(
      find.textContaining('You can join beginning at').evaluate(),
    ).isEmpty();

    await tester.tap(find.text('Join Session'));
    await _settleNotice(tester);

    check(joined).equals(0);
    check(find.text('BEFORE YOU JOIN').evaluate()).isNotEmpty();
    check(_noteHugsTheBottom(tester)).isTrue();

    await tester.tap(find.text('Got it'));
    await _settleNotice(tester);

    check(find.text('BEFORE YOU JOIN').evaluate()).isEmpty();
  });

  testWidgets('the same note is a dialog on a wide window', (tester) async {
    await _setSize(tester, const Size(1280, 760));

    await tester.pumpWidget(_host(phase: EntryPhase.tooEarly));
    await tester.pump();

    await tester.tap(find.text('Join Session'));
    await _settleNotice(tester);

    check(find.text('BEFORE YOU JOIN').evaluate()).isNotEmpty();
    check(_noteHugsTheBottom(tester)).isFalse();
    // The card wraps the note. A stretched dialog fills the 760 frame.
    check(_noteCardHeight(tester)).isLessThan(420);
  });

  testWidgets('Join enters the room once the window is open', (tester) async {
    await _setSize(tester, const Size(360, 812));
    var joined = 0;

    await tester.pumpWidget(
      _host(phase: EntryPhase.joinWindow, onJoin: () => joined++),
    );
    await tester.pump();

    await tester.tap(find.text('Join Session'));
    await tester.pump();

    check(joined).equals(1);
    check(find.text('BEFORE YOU JOIN').evaluate()).isEmpty();
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// The layer waits a frame to measure, then springs. Reduced motion
/// skips the spring and lands on the resting spot.
Future<void> _settleNotice(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Widget _host({required EntryPhase phase, VoidCallback? onJoin}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: TotemTheme.themeData(Brightness.light),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: SessionEntry(
      role: EntryRole.participant,
      phase: phase,
      status: EntryStatus.browsing,
      onJoin: onJoin,
    ),
  );
}

/// A phone sheet sits on the bottom edge and starts partway down.
/// A dialog floats in the middle, so nothing between the note and the
/// full screen both hugs the bottom and leaves a gap above.
bool _noteHugsTheBottom(WidgetTester tester) {
  final screen = tester.renderObject<RenderBox>(find.byType(SessionEntry));
  final screenBottom =
      screen.localToGlobal(Offset.zero).dy + screen.size.height;
  RenderObject? node = tester.renderObject(find.text('BEFORE YOU JOIN'));

  while (node != null) {
    if (node is RenderBox && node.hasSize) {
      final top = node.localToGlobal(Offset.zero).dy;
      final bottom = top + node.size.height;
      final hugsBottom = (bottom - screenBottom).abs() < 1;
      final shorterThanTheScreen = node.size.height < screen.size.height - 1;
      if (hugsBottom && top > 40 && shorterThanTheScreen) return true;
    }
    node = node.parent;
  }
  return false;
}

/// Height of the white card around the note.
double _noteCardHeight(WidgetTester tester) {
  RenderObject? node = tester.renderObject(find.text('BEFORE YOU JOIN'));
  while (node != null) {
    if (node is RenderDecoratedBox && node.hasSize) return node.size.height;
    node = node.parent;
  }
  return double.infinity;
}
