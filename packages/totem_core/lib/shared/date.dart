import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

/// Formats date as "Today", "Tomorrow", or short format like "5 Feb".
/// Used for compact date displays in cards.
String formatShortDate(DateTime dateTime) {
  final now = DateTime.now();
  final date = dateTime.toLocal();

  if (DateUtils.isSameDay(now, date)) {
    return 'Today';
  }

  final tomorrow = now.add(const Duration(days: 1));
  if (DateUtils.isSameDay(tomorrow, date)) {
    return 'Tomorrow';
  }

  return DateFormat('d MMM').format(date);
}

/// Formats time without period (e.g., "4:00").
String formatTimeOnly(DateTime dateTime) {
  return DateFormat('h:mm').format(dateTime.toLocal());
}

/// Formats time period only (e.g., "AM" or "PM").
String formatTimePeriod(DateTime dateTime) {
  return DateFormat('a').format(dateTime.toLocal());
}

String formatSessionDate(DateTime dateTime) {
  try {
    final date = dateTime.toLocal();

    final isToday = DateUtils.isSameDay(DateTime.now(), date);
    if (isToday) return 'Today';
    final isTomorrow = DateUtils.isSameDay(
      DateTime.now().add(const Duration(days: 1)),
      date,
    );
    if (isTomorrow) return 'Tomorrow';

    final dateFormat = DateFormat('EEEE, MMM d'); // e.g., Monday, Jan 1
    return dateFormat.format(date);
  } catch (error) {
    return 'Date TBA';
  }
}

String formatSessionTime(DateTime dateTime, [String? userTimezone]) {
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
