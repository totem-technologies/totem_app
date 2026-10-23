import 'package:flutter/services.dart';

final class AppCalendarEvent {
  const AppCalendarEvent({
    required this.title,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    this.allDay = false,
    this.reminderMinutesBefore,
  });

  final String title;
  final String description;
  final String location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final int? reminderMinutesBefore;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'allDay': allDay,
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }
}

class CalendarService {
  static const _channel = MethodChannel('org.totem.calendar');

  static Future<bool> addToCalendar(AppCalendarEvent event) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'addToCalendar',
        event.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
