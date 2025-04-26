import 'package:intl/intl.dart';

String formatEventDate(String isoUtcString) {
  try {
    final dateTime = DateTime.parse(isoUtcString);
    final dateFormat = DateFormat.yMMMEd();
    return dateFormat.format(dateTime);
  } catch (e) {
    return 'Date TBA';
  }
}

String formatEventTime(String isoUtcString) {
  try {
    final dateTime = DateTime.parse(isoUtcString);
    final timeFormat = DateFormat.jm(); // e.g., 2:30 PM
    return timeFormat.format(dateTime);
  } catch (e) {
    return 'Time TBA';
  }
}

String formatEventDateTime(String isoUtcString) {
  try {
    final dateTime = DateTime.parse(isoUtcString);
    final dateFormat = DateFormat.yMMMd(); // e.g., Apr 27, 2023
    final timeFormat = DateFormat.jm(); // e.g., 2:30 PM
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  } catch (e) {
    return 'Date TBA';
  }
}
