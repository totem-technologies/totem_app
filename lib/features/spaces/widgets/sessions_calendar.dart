import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:totem_app/api/models/next_event_schema.dart';
import 'package:totem_app/core/config/theme.dart';

class SessionsCalendar extends StatefulWidget {
  const SessionsCalendar({
    required this.nextEvents,
    super.key,
  });

  /// List of upcoming events to highlight on the calendar
  /// The calendar will automatically start on the month of the first event,
  /// or the current month if no events are available
  final List<NextEventSchema> nextEvents;

  @override
  State<SessionsCalendar> createState() => _SessionsCalendarState();
}

class _SessionsCalendarState extends State<SessionsCalendar> {
  // Day abbreviations for the calendar header
  static const List<String> days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  // Current month being displayed
  // Automatically determined from nextEvents or defaults to current month
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    // Determine the starting month from nextEvents
    // Use the first event's month if available,
    // otherwise default to current month
    final firstEvent = widget.nextEvents.firstOrNull;
    if (firstEvent != null) {
      // Start on the month of the first upcoming event
      _currentMonth = DateTime(
        firstEvent.start.year,
        firstEvent.start.month,
      );
    } else {
      // No events available, default to current month
      _currentMonth = DateTime.now();
    }
  }

  // Navigate to the previous month
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  // Navigate to the next month
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  // Get the formatted month and year string (e.g., "November 2025")
  String get _monthYearString {
    return DateFormat('MMMM yyyy').format(_currentMonth);
  }

  // Calculate the number of days in the current month
  int get _daysInMonth {
    return DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
  }

  // Calculate the number of days in the previous month
  int get _daysInPreviousMonth {
    return DateTime(_currentMonth.year, _currentMonth.month, 0).day;
  }

  // Get the day of week for the first day of the month
  // (0 = Sunday, 6 = Saturday)
  int get _firstDayOfWeek {
    return DateTime(_currentMonth.year, _currentMonth.month).weekday % 7;
  }

  // Generate the list of DateTime objects to display in the calendar grid
  // Fills empty cells with dates from previous and next months
  List<DateTime?> _generateCalendarDays() {
    final List<DateTime?> days = List.filled(35, null);

    // Fill in days from the previous month
    // (before the first day of current month)
    final firstDayIndex = _firstDayOfWeek;
    if (firstDayIndex > 0) {
      // Calculate how many days we need from the previous month
      final daysFromPreviousMonth = firstDayIndex;
      final previousMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
      );
      for (int i = 0; i < daysFromPreviousMonth; i++) {
        // Start from the last days of the previous month
        final dayNumber = _daysInPreviousMonth - daysFromPreviousMonth + i + 1;
        days[i] = DateTime(previousMonth.year, previousMonth.month, dayNumber);
      }
    }

    // Fill in the days of the current month
    for (int day = 1; day <= _daysInMonth; day++) {
      final dayIndex = _firstDayOfWeek + day - 1;
      if (dayIndex < 35) {
        days[dayIndex] = DateTime(_currentMonth.year, _currentMonth.month, day);
      }
    }

    // Fill in days from the next month (after the last day of current month)
    final lastDayIndex = _firstDayOfWeek + _daysInMonth - 1;
    final remainingCells = 35 - (lastDayIndex + 1);
    if (remainingCells > 0) {
      final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      for (int i = 0; i < remainingCells; i++) {
        final dayIndex = lastDayIndex + 1 + i;
        if (dayIndex < 35) {
          days[dayIndex] = DateTime(nextMonth.year, nextMonth.month, i + 1);
        }
      }
    }

    return days;
  }

  // Check if a DateTime belongs to the current month being displayed
  // Returns true if it's from the current month, false if from previous/next month
  bool _isCurrentMonth(DateTime? day) {
    if (day == null) return false;
    return day.year == _currentMonth.year && day.month == _currentMonth.month;
  }

  // Check if a given day matches any event date from nextEvents
  // Compares only year/month/day (ignoring time) to determine if it's an event day
  bool _isEventDay(DateTime? day) {
    if (day == null) return false;

    // Normalize the calendar day to just year/month/day for comparison
    final dayDate = DateTime(day.year, day.month, day.day);

    // Check if any event's start date matches this day
    return widget.nextEvents.any((event) {
      // Normalize event start date to just year/month/day for comparison
      final eventDate = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      return dayDate == eventDate;
    });
  }

  bool _isEventOpen(DateTime? day) {
    if (day == null) return false;

    // Normalize the calendar day to just year/month/day for comparison
    final dayDate = DateTime(day.year, day.month, day.day);

    // Check if any event's start date matches this day
    return widget.nextEvents.any((event) {
      // Normalize event start date to just year/month/day for comparison
      final eventDate = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      return dayDate == eventDate && event.open;
    });
  }

  bool _isUserAttending(DateTime? day) {
    if (day == null) return false;

    // Normalize the calendar day to just year/month/day for comparison
    final dayDate = DateTime(day.year, day.month, day.day);

    // Check if any event's start date matches
    // this day and the user is attending the event
    return widget.nextEvents.any((event) {
      // Normalize event start date to just year/month/day for comparison
      final eventDate = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      return dayDate == eventDate && event.attending;
    });
  }

  // Builds the widget for a single day cell in the calendar
  // Handles rendering of day numbers, event day highlighting, and styling
  Widget _buildDayCell(DateTime? day, bool isCurrentMonth) {
    // Return empty widget for null days (empty calendar cells)
    if (day == null) {
      return const SizedBox.shrink();
    }

    // Check if this day is an event day (has a scheduled session)
    final isEventDay = _isEventDay(day);

    if (!isEventDay) {
      return Container(
        margin: const EdgeInsetsDirectional.all(5),
        width: 25,
        height: 25,
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              // White text for event days, otherwise black/grey based on current month
              color: isEventDay
                  ? Colors.white
                  : (isCurrentMonth ? Colors.black : Colors.grey),
            ),
          ),
        ),
      );
    }

    if (_isUserAttending(day)) {
      return Container(
        margin: const EdgeInsetsDirectional.all(5),
        width: 25,
        height: 25,
        decoration: const BoxDecoration(
          color: AppTheme.mauve,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: const TextStyle(
              color: AppTheme.white,
            ),
          ),
        ),
      );
    } else if (_isEventOpen(day)) {
      return Container(
        margin: const EdgeInsetsDirectional.all(5),
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.mauve,
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate,
            ),
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsetsDirectional.all(5),
        width: 25,
        height: 25,
        decoration: const BoxDecoration(
          color: AppTheme.grey,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: const TextStyle(
              color: AppTheme.white,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarDays = _generateCalendarDays();

    return Container(
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 24,
                ),
                Text(_monthYearString),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 24,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                7,
                (index) => Text(days[index]),
              ).toList(),
            ),
          ),
          GridView.builder(
            itemCount: 35,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsetsDirectional.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, index) {
              final day = calendarDays[index];
              final isCurrentMonth = _isCurrentMonth(day);
              return _buildDayCell(day, isCurrentMonth);
            },
          ),
        ],
      ),
    );
  }
}
