import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_widgetbook/design/components/session_card/session_card.dart';

void main() {
  Widget host({VoidCallback? onAddToCalendar}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 362,
        child: SessionCard(
          photo: const AssetImage('assets/design/sessions/photo-mother.jpg'),
          spaceName: 'Thriving in Motherhood',
          sessionName: 'The Weight of Expectations',
          keeperName: 'Maria',
          time: '4:00',
          meridiem: 'PM',
          seatsLeft: 4,
          onAddToCalendar: onAddToCalendar,
        ),
      ),
    ),
  );

  testWidgets('screen readers reach the calendar button', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(host(onAddToCalendar: () => taps++));

    expect(
      find.bySemanticsLabel(
        'The Weight of Expectations, 4:00 PM, 4 seats left, with Maria',
      ),
      findsOneWidget,
    );
    final button = find.bySemanticsLabel('Add to calendar');
    expect(button, findsOneWidget);

    await tester.tap(button);
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('no calendar button without a handler', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());

    expect(find.bySemanticsLabel('Add to calendar'), findsNothing);
    handle.dispose();
  });
}
