import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_widgetbook/design/design.dart';

/// The Session details page: seats, the ended dialog, and the wide column.
void main() {
  testWidgets('an open Session with no seats left reads as full', (
    tester,
  ) async {
    var attended = 0;

    await tester.pumpWidget(_host(seatsLeft: 0, onAttend: () => attended++));
    await tester.pump();

    check(find.text('Full').evaluate()).isNotEmpty();
    check(find.text('Attend').evaluate()).isEmpty();

    await tester.tap(find.text('Full'));
    check(attended).equals(0);
  });

  testWidgets('a negative seat count shows none left', (tester) async {
    await tester.pumpWidget(_host(seatsLeft: -3));
    await tester.pump();

    check(find.textContaining('-3').evaluate()).isEmpty();
    check(find.text('Full').evaluate()).isNotEmpty();
  });

  testWidgets('nothing behind the ended dialog takes focus', (tester) async {
    await tester.pumpWidget(_host(status: SessionDetailsStatus.ended));
    await tester.pump();

    final page = find.byType(ListView);
    final excluded = tester.widget<ExcludeFocus>(
      find.ancestor(of: page, matching: find.byType(ExcludeFocus)).first,
    );
    check(excluded.excluding).isTrue();
  });

  testWidgets('a wide window centers a 560px column', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host());
    await tester.pump();

    final card = tester.getRect(find.text('About this Session'));
    check(card.left).equals((1280 - 560) / 2 + 20);
  });
}

Widget _host({
  SessionDetailsStatus status = SessionDetailsStatus.open,
  int seatsLeft = 9,
  VoidCallback? onAttend,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: TotemTheme.themeData(Brightness.light),
    home: SessionDetailsPage(
      spaceName: 'A Space',
      sessionName: 'A Session',
      keeperName: 'Vanessa',
      keeperBio: 'Bio.',
      dateLabel: 'Wednesday, February 11th',
      timeLabel: '12:30 AM GMT+1',
      description: 'About.',
      status: status,
      seatsLeft: seatsLeft,
      onAttend: onAttend,
    ),
  );
}
