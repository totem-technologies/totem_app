import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/spaces/widgets/sessions_calendar.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

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

void main() {
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
