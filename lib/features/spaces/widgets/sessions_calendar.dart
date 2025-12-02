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
  static const List<String> days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final firstEvent = widget.nextEvents.firstOrNull;
    if (firstEvent != null) {
      _currentMonth = DateTime(
        firstEvent.start.year,
        firstEvent.start.month,
      );
    } else {
      _currentMonth = DateTime.now();
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  String get _monthYearString {
    return DateFormat('MMMM yyyy').format(_currentMonth);
  }

  int get _daysInMonth {
    return DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
  }

  int get _daysInPreviousMonth {
    return DateTime(_currentMonth.year, _currentMonth.month, 0).day;
  }

  // (0 = Sunday, 6 = Saturday)
  int get _firstDayOfWeek {
    return DateTime(_currentMonth.year, _currentMonth.month).weekday % 7;
  }

  List<DateTime?> _generateCalendarDays() {
    final List<DateTime?> days = List.filled(35, null);

    final firstDayIndex = _firstDayOfWeek;
    if (firstDayIndex > 0) {
      final daysFromPreviousMonth = firstDayIndex;
      final previousMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
      );
      for (int i = 0; i < daysFromPreviousMonth; i++) {
        final dayNumber = _daysInPreviousMonth - daysFromPreviousMonth + i + 1;
        days[i] = DateTime(previousMonth.year, previousMonth.month, dayNumber);
      }
    }

    for (int day = 1; day <= _daysInMonth; day++) {
      final dayIndex = _firstDayOfWeek + day - 1;
      if (dayIndex < 35) {
        days[dayIndex] = DateTime(_currentMonth.year, _currentMonth.month, day);
      }
    }

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

  bool _isCurrentMonth(DateTime? day) {
    if (day == null) return false;
    return day.year == _currentMonth.year && day.month == _currentMonth.month;
  }

  // Normalize a DateTime to just year/month/day, removing time components
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Compares only year/month/day (ignoring time) to determine if it's an event day
  bool _isEventDay(DateTime? day) {
    if (day == null) return false;

    final dayDate = _normalizeDate(day);

    return widget.nextEvents.any((event) {
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate;
    });
  }

  // Compares only year/month/day (ignoring time) to determine if it's an open event day
  bool _isEventOpen(DateTime? day) {
    if (day == null) return false;

    final dayDate = _normalizeDate(day);

    return widget.nextEvents.any((event) {
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate && event.open;
    });
  }

  // Compares only year/month/day (ignoring time) to determine if it's an attended event day
  bool _isUserAttending(DateTime? day) {
    if (day == null) return false;

    final dayDate = _normalizeDate(day);

    return widget.nextEvents.any((event) {
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate && event.attending;
    });
  }

  List<NextEventSchema> _getEventsForDay(DateTime? day) {
    if (day == null) return [];

    final dayDate = _normalizeDate(day);

    return widget.nextEvents.where((event) {
      final eventDate = _normalizeDate(event.start);
      return dayDate == eventDate;
    }).toList();
  }

  // Provides descriptive text for screen readers
  String _getDaySemanticLabel(DateTime? day, bool isCurrentMonth) {
    if (day == null) return '';

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

    final monthName = DateFormat('MMMM').format(day);

    final baseLabel = '$ordinal of $monthName';

    if (!_isEventDay(day)) {
      if (!isCurrentMonth) {
        return '$baseLabel, not in current month';
      }
      return '$baseLabel, no event scheduled';
    }

    final events = _getEventsForDay(day);
    final event = events.first;

    String statusLabel;
    if (_isUserAttending(day)) {
      statusLabel = 'attending event';
    } else if (_isEventOpen(day)) {
      statusLabel = 'open event';
    } else {
      statusLabel = 'event';
    }

    if (event.title != null && event.title!.isNotEmpty) {
      return '$baseLabel, $statusLabel: ${event.title}';
    }

    return '$baseLabel, $statusLabel';
  }

  Widget _buildDayCell(DateTime? day, bool isCurrentMonth) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final isEventDay = _isEventDay(day);

    final eventsForDay = _getEventsForDay(day);

    Widget dayCellContent;

    if (!isEventDay) {
      dayCellContent = Container(
        margin: const EdgeInsetsDirectional.all(5),
        width: 25,
        height: 25,
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: (isCurrentMonth ? Colors.black : Colors.grey),
            ),
          ),
        ),
      );
    } else if (_isUserAttending(day)) {
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

    final Widget accessibleDayCell = Semantics(
      label: _getDaySemanticLabel(day, isCurrentMonth),
      button: isEventDay && widget.onEventDayTap != null,
      onTap: isEventDay && widget.onEventDayTap != null
          ? () {
              widget.onEventDayTap!(day, eventsForDay);
            }
          : null,
      child: dayCellContent,
    );

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
