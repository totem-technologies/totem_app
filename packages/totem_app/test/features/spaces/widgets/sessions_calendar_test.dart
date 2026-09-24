import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/spaces/widgets/sessions_calendar.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';

NextSessionSchema _session(
  DateTime start, {
  bool attending = false,
  bool open = false,
}) => NextSessionSchema(
  title: 'Session',
  slug: 'session-${start.millisecondsSinceEpoch}',
  start: start,
  link: 'https://example.com/session',
  seatsLeft: 10,
  duration: 60,
  meetingProvider: MeetingProviderEnum.livekit,
  calLink: 'https://example.com/calendar',
  attending: attending,
  cancelled: false,
  open: open,
  joinable: false,
);

Future<void> _pumpCalendar(
  WidgetTester tester,
  List<NextSessionSchema> sessions, {
  void Function(DateTime, List<NextSessionSchema>)? onDayTap,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 350,
          child: SessionsCalendar(
            nextSessions: sessions,
            onSessionDayTap: onDayTap,
          ),
        ),
      ),
    ),
  ),
);

BoxDecoration _decoration(WidgetTester tester, String day) =>
    tester
            .widget<DecoratedBox>(
              find.ancestor(
                of: find.text(day),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('empty calendar shows a month heading and weekday labels', (
    tester,
  ) async {
    await _pumpCalendar(tester, []);

    check(
      tester.widgetList(find.textContaining(RegExp(r'^\w+ \d{4}$'))),
    ).length.equals(1);
    final weekdays = tester.widgetList<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && RegExp(r'^[SMTWF]$').hasMatch(widget.data ?? ''),
      ),
    );
    check(
      weekdays.map((text) => text.data),
    ).deepEquals(['S', 'M', 'T', 'W', 'T', 'F', 'S']);
  });

  testWidgets(
    'starts at the first session and navigates months across a year',
    (tester) async {
      await _pumpCalendar(tester, [
        _session(DateTime(2025, 1, 15)),
        _session(DateTime(2024, 12, 20)),
        _session(DateTime(2025, 2, 10)),
      ]);
      check(tester.widgetList(find.text('January 2025'))).length.equals(1);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      check(tester.widgetList(find.text('December 2024'))).length.equals(1);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      check(tester.widgetList(find.text('January 2025'))).length.equals(1);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      check(tester.widgetList(find.text('February 2025'))).length.equals(1);
    },
  );

  for (final month in [
    (
      number: 5,
      days: [
        ...List.generate(4, (i) => '${27 + i}'),
        ...List.generate(31, (i) => '${i + 1}'),
      ],
      outsideIndex: 0,
    ),
    (
      number: 6,
      days: [
        ...List.generate(30, (i) => '${i + 1}'),
        ...List.generate(5, (i) => '${i + 1}'),
      ],
      outsideIndex: 34,
    ),
  ]) {
    testWidgets('lays out month ${month.number} with adjacent-month days', (
      tester,
    ) async {
      await _pumpCalendar(tester, [_session(DateTime(2025, month.number, 20))]);
      final days = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Text),
            ),
          )
          .toList();

      check(days.map((text) => text.data)).deepEquals(month.days);
    });
  }

  testWidgets(
    'styles session states and prioritizes attending over open sessions',
    (tester) async {
      await _pumpCalendar(tester, [
        _session(DateTime(2025, 6, 15)),
        _session(DateTime(2025, 6, 16), open: true),
        _session(DateTime(2025, 6, 17, 10), open: true),
        _session(DateTime(2025, 6, 17, 14), attending: true),
      ]);

      final closed = _decoration(tester, '15');
      check(closed.color).equals(AppTheme.grey);
      check(closed.shape).equals(BoxShape.circle);
      final open = _decoration(tester, '16');
      check(open.border?.top.color).equals(AppTheme.mauve);
      check(open.shape).equals(BoxShape.circle);

      final attending = _decoration(tester, '17');
      check(attending.color).equals(AppTheme.mauve);
      check(attending.border).isNull();
      check(attending.shape).equals(BoxShape.circle);

      check(
        tester.widgetList(
          find.ancestor(
            of: find.text('20'),
            matching: find.byType(DecoratedBox),
          ),
        ),
      ).isEmpty();

      // Session days also render safely when no tap callback is supplied.
      await tester.tap(find.text('16'));
      await tester.pump();
      check(_decoration(tester, '16').border?.top.color).equals(AppTheme.mauve);
    },
  );

  testWidgets('taps return only sessions on that date, ignoring their times', (
    tester,
  ) async {
    final sessions = [
      _session(DateTime(2025, 6, 15)),
      _session(DateTime(2025, 6, 15, 23, 59)),
      _session(DateTime(2025, 6, 16)),
    ];
    final taps = <(DateTime, List<NextSessionSchema>)>[];
    await _pumpCalendar(
      tester,
      sessions,
      onDayTap: (day, events) => taps.add((day, events)),
    );

    await tester.tap(find.text('20'));
    await tester.pump();
    check(taps).isEmpty();

    await tester.tap(find.text('15'));
    await tester.pump();
    check(taps).length.equals(1);
    check(taps.single.$1).equals(DateTime(2025, 6, 15));
    check(taps.single.$2).deepEquals(sessions.take(2));

    await tester.tap(find.text('16'));
    await tester.pump();
    check(taps).length.equals(2);
    check(taps.last.$1).equals(DateTime(2025, 6, 16));
    check(taps.last.$2).deepEquals([sessions.last]);
  });
}
