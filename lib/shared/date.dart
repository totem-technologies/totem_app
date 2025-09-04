import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

String formatEventDate(DateTime dateTime) {
  try {
    final date = dateTime.toLocal();

    final isToday = DateUtils.isSameDay(DateTime.now(), date);
    if (isToday) return 'Today';
    final isTomorrow = DateUtils.isSameDay(
      DateTime.now().add(const Duration(days: 1)),
      date,
    );
    if (isTomorrow) return 'Tomorrow';

    final dateFormat = DateFormat.MMMMEEEEd();
    return dateFormat.format(date);
  } catch (error) {
    return 'Date TBA';
  }
}

String formatEventTime(DateTime dateTime, [String? userTimezone]) {
  try {
    final date = dateTime.toLocal();
    final timeFormat = DateFormat.jm(); // e.g., 2:30 PM
    return '${timeFormat.format(date)} ${userTimezone ?? ''}'.trim();
  } catch (error) {
    return 'Time TBA';
  }
}

String buildTimeLabel(DateTime start) {
  try {
    final now = DateTime.now();
    final date = start.toLocal();
    final isToday = DateUtils.isSameDay(now, date);

    final timeFormatter = DateFormat('hh:mm a');

    if (isToday) return 'Today, ${timeFormatter.format(date)}';

    final isTomorrow = DateUtils.isSameDay(
      now.add(const Duration(days: 1)),
      date,
    );
    if (isTomorrow) return 'Tomorrow, ${timeFormatter.format(date)}';

    final dateFormatter = DateFormat('E MMM dd');
    return '${dateFormatter.format(date)}, ${timeFormatter.format(date)}';
  } catch (error) {
    return 'Time TBA';
  }
}
