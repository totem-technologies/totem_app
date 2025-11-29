import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:totem_app/api/models/next_event_schema.dart';
import 'package:totem_app/core/config/theme.dart';

class SessionsCalendar extends StatefulWidget {
  const SessionsCalendar({
    required this.nextEvents,
    this.onEventDayTap,
    super.key,
  });

  /// List of upcoming events to highlight on the calendar
  /// The calendar will automatically start on the month of the first event,
  /// or the current month if no events are available
  final List<NextEventSchema> nextEvents;

  /// Optional callback when an event day is tapped
  /// Provides the list of events for that day and the day's DateTime
  final void Function(DateTime day, List<NextEventSchema> events)?
  onEventDayTap;

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

  // Normalize a DateTime to just year/month/day, removing time components
  // This ensures consistent date comparisons regardless of time values
  // Used throughout the calendar to compare dates without considering hours/minutes/seconds
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Check if a given day matches any event date from nextEvents
  // Compares only year/month/day (ignoring time) to determine if it's an event day
  bool _isEventDay(DateTime? day) {
    if (day == null) return false;

    // Normalize the calendar day to just year/month/day for comparison
    final dayDate = _normalizeDate(day);

    // Check if any event's start date matches this day
    return widget.nextEvents.any((event) {
      // Normalize event start date to just year/month/day for comparison
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate;
    });
  }

  bool _isEventOpen(DateTime? day) {
    if (day == null) return false;

    // Normalize the calendar day to just year/month/day for comparison
    final dayDate = _normalizeDate(day);

    // Check if any event's start date matches this day
    return widget.nextEvents.any((event) {
      // Normalize event start date to just year/month/day for comparison
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate && event.open;
    });
  }

  bool _isUserAttending(DateTime? day) {
    if (day == null) return false;

    // Normalize the calendar day to just year/month/day for comparison
    final dayDate = _normalizeDate(day);

    // Check if any event's start date matches
    // this day and the user is attending the event
    return widget.nextEvents.any((event) {
      // Normalize event start date to just year/month/day for comparison
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate && event.attending;
    });
  }

  // Get all events for a specific day
  // Returns a list of events that occur on the given day
  List<NextEventSchema> _getEventsForDay(DateTime? day) {
    if (day == null) return [];

    // Normalize the calendar day to just year/month/day for comparison
    final dayDate = _normalizeDate(day);

    // Filter events that match this day
    return widget.nextEvents.where((event) {
      // Normalize event start date to just year/month/day for comparison
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate;
    }).toList();
  }

  // Generate an accessible semantic label for a day cell
  // Provides descriptive text for screen readers indicating the day,
  // month, and event status
  String _getDaySemanticLabel(DateTime? day, bool isCurrentMonth) {
    if (day == null) return '';

    // Format the day with ordinal suffix (1st, 2nd, 3rd, etc.)
    final dayNumber = day.day;
    String ordinal;
    if (dayNumber % 10 == 1 && dayNumber % 100 != 11) {
      ordinal = '${dayNumber}st';
    } else if (dayNumber % 10 == 2 && dayNumber % 100 != 12) {
      ordinal = '${dayNumber}nd';
    } else if (dayNumber % 10 == 3 && dayNumber % 100 != 13) {
      ordinal = '${dayNumber}rd';
    } else {
      ordinal = '${dayNumber}th';
    }

    // Get month name
    final monthName = DateFormat('MMMM').format(day);

    // Build base label with day and month
    final baseLabel = '$ordinal of $monthName';

    // Check event status and add descriptive text
    if (!_isEventDay(day)) {
      // No event on this day
      if (!isCurrentMonth) {
        return '$baseLabel, not in current month';
      }
      return '$baseLabel, no event scheduled';
    }

    // There's an event on this day - get details
    final events = _getEventsForDay(day);
    final event = events.first; // Use first event for label (usually only one)

    // Build event status description
    String statusLabel;
    if (_isUserAttending(day)) {
      statusLabel = 'attending event';
    } else if (_isEventOpen(day)) {
      statusLabel = 'open event';
    } else {
      statusLabel = 'event';
    }

    // Add event title if available
    if (event.title != null && event.title!.isNotEmpty) {
      return '$baseLabel, $statusLabel: ${event.title}';
    }

    return '$baseLabel, $statusLabel';
  }

  // Builds the widget for a single day cell in the calendar
  // Handles rendering of day numbers, event day highlighting, styling,
  // accessibility labels, and tap handlers for event days
  Widget _buildDayCell(DateTime? day, bool isCurrentMonth) {
    // Return empty widget for null days (empty calendar cells)
    if (day == null) {
      return const SizedBox.shrink();
    }

    // Check if this day is an event day (has a scheduled session)
    final isEventDay = _isEventDay(day);

    // Get events for this day (for tap handler)
    final eventsForDay = _getEventsForDay(day);

    // Build the day cell content widget
    Widget dayCellContent;

    if (!isEventDay) {
      // Regular day with no event
      dayCellContent = Container(
        margin: const EdgeInsetsDirectional.all(5),
        width: 25,
        height: 25,
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              // black/grey based on current month
              color: (isCurrentMonth ? Colors.black : Colors.grey),
            ),
          ),
        ),
      );
    } else if (_isUserAttending(day)) {
      // Event day where user is attending
      dayCellContent = Container(
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
      // Event day that is open (available to join)
      dayCellContent = Container(
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
      // Event day that is not open or user is not attending
      dayCellContent = Container(
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

    // Wrap with Semantics for accessibility
    // Provides descriptive labels for screen readers
    final Widget accessibleDayCell = Semantics(
      label: _getDaySemanticLabel(day, isCurrentMonth),
      // Make event days tappable for keyboard/screen reader navigation
      button: isEventDay && widget.onEventDayTap != null,
      // Enable tap actions for event days
      onTap: isEventDay && widget.onEventDayTap != null
          ? () {
              widget.onEventDayTap!(day, eventsForDay);
            }
          : null,
      child: dayCellContent,
    );

    // Wrap event days with GestureDetector for tap handling
    // This enables both touch and keyboard/screen reader interaction
    if (isEventDay && widget.onEventDayTap != null) {
      return GestureDetector(
        onTap: () {
          widget.onEventDayTap!(day, eventsForDay);
        },
        child: accessibleDayCell,
      );
    }

    return accessibleDayCell;
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
                // Previous month navigation button with accessibility label
                Semantics(
                  label: 'Previous month',
                  button: true,
                  child: IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left),
                    iconSize: 24,
                  ),
                ),
                Text(_monthYearString),
                // Next month navigation button with accessibility label
                Semantics(
                  label: 'Next month',
                  button: true,
                  child: IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                    iconSize: 24,
                  ),
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
