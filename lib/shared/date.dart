import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

String formatEventDate(DateTime dateTime) {
  try {
    final date = dateTime.toLocal();
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

String formatEventDateTime(DateTime dateTime, [String? userTimezone]) {
  try {
    final date = dateTime.toLocal();
    final dateFormat = DateFormat.yMMMd(); // e.g., Apr 27, 2023
    final timeFormat = DateFormat.jm(); // e.g., 2:30 PM
    return '${dateFormat.format(date)}'
            ' at '
            '${timeFormat.format(date)} '
            '${userTimezone ?? ''}'
        .trim();
  } catch (error) {
    return 'Date TBA';
  }
}

String buildTimeLabel(DateTime start) {
  try {
    final now = DateTime.now();
    final date = start.toLocal();
    final isToday = DateUtils.isSameDay(now, date);

    final timeFormatter = DateFormat('hh:mm a');

    if (isToday) {
      return 'Today, ${timeFormatter.format(date)}';
    }

    final dateFormatter = DateFormat('E MMM dd');
    return '${dateFormatter.format(date)}, ${timeFormatter.format(date)}';
  } catch (error) {
    return 'Time TBA';
  }
}
