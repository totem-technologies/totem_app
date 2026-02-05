import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/spaces/widgets/session_card.dart';

class SessionDateGroup {
  const SessionDateGroup({required this.date, required this.sessions});

  final DateTime date;
  final List<UpcomingSessionData> sessions;
}

class SessionDateGroupWidget extends StatelessWidget {
  const SessionDateGroupWidget({
    required this.dateGroup,
    required this.today,
    super.key,
  });

  final SessionDateGroup dateGroup;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(dateGroup.date, today);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateIndicator(date: dateGroup.date, isToday: isToday),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < dateGroup.sessions.length; i++) ...[
                  SessionCard(data: dateGroup.sessions[i]),
                  if (i < dateGroup.sessions.length - 1)
                    const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DateIndicator extends StatelessWidget {
  const DateIndicator({
    required this.date,
    required this.isToday,
    super.key,
  });

  final DateTime date;
  final bool isToday;

  static const _width = 50.0;
  static const _height = 70.0;
  static const _borderRadius = 10.0;

  @override
  Widget build(BuildContext context) {
    final dayNumber = date.day.toString();
    final dayOfWeek = DateFormat('E').format(date);
    final monthName = DateFormat('MMM').format(date);

    return SizedBox(
      width: _width,
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        child: isToday
            ? _buildTodayContent(dayNumber, dayOfWeek)
            : _buildDateContent(dayNumber, dayOfWeek, monthName),
      ),
    );
  }

  Widget _buildTodayContent(String dayNumber, String dayOfWeek) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: const BoxDecoration(
              color: AppTheme.mauve,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_borderRadius),
              ),
            ),
            child: Text(
              '$dayNumber ${dayOfWeek.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Today',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateContent(
    String dayNumber,
    String dayOfWeek,
    String monthName,
  ) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gray.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_borderRadius),
              ),
            ),
            child: Text(
              monthName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepGray,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gray,
                  height: 1.2,
                ),
              ),
              Text(
                dayOfWeek.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.gray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
