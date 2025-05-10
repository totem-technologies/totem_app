import 'package:intl/intl.dart';

String formatEventDate(DateTime dateTime) {
  try {
    final dateFormat = DateFormat.yMMMEd();
    return dateFormat.format(dateTime);
  } catch (error) {
    return 'Date TBA';
  }
}

String formatEventTime(DateTime dateTime) {
  try {
    final timeFormat = DateFormat.jm(); // e.g., 2:30 PM
    return timeFormat.format(dateTime);
  } catch (error) {
    return 'Time TBA';
  }
}

String formatEventDateTime(DateTime dateTime) {
  try {
    final dateFormat = DateFormat.yMMMd(); // e.g., Apr 27, 2023
    final timeFormat = DateFormat.jm(); // e.g., 2:30 PM
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  } catch (error) {
    return 'Date TBA';
  }
}
