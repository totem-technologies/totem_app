import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/services/calendar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.totem.calendar');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'sends the calendar event payload and returns the platform result',
    () async {
      MethodCall? receivedCall;
      messenger.setMockMethodCallHandler(channel, (call) async {
        receivedCall = call;
        return true;
      });
      final event = AppCalendarEvent(
        title: 'Session',
        description: 'A session',
        location: 'Room 1',
        start: DateTime.utc(2026, 1, 2, 10),
        end: DateTime.utc(2026, 1, 2, 11),
        allDay: true,
        reminderMinutesBefore: 15,
      );

      check(await CalendarService.addToCalendar(event)).equals(true);
      check(receivedCall!.method).equals('addToCalendar');
      check(
        jsonEncode(receivedCall!.arguments),
      ).equals(jsonEncode(event.toMap()));
    },
  );

  test('returns false for a null platform result', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    check(await CalendarService.addToCalendar(_event())).equals(false);
  });

  test('returns false when the platform reports a failure', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'calendar_unavailable'),
    );

    check(await CalendarService.addToCalendar(_event())).equals(false);
  });
}

AppCalendarEvent _event() => AppCalendarEvent(
  title: 'Session',
  description: 'Description',
  location: 'Location',
  start: DateTime.utc(2026, 1, 2, 10),
  end: DateTime.utc(2026, 1, 2, 11),
);
