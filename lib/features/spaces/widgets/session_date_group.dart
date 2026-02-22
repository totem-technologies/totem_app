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

class SliverStickyDateGroup extends StatelessWidget {
  const SliverStickyDateGroup({
    required this.dateGroup,
    required this.today,
    super.key,
  });

  final SessionDateGroup dateGroup;
  final DateTime today;

  static const double dateColumnWidth =
      DateIndicator._width + 16 + 12; // left pad + width + gap

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(dateGroup.date, today);

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 16),
          sliver: SliverCrossAxisGroup(
            slivers: [
              SliverConstrainedCrossAxis(
                maxExtent: dateColumnWidth,
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _DateIndicatorHeaderDelegate(
                    date: dateGroup.date,
                    isToday: isToday,
                    scaler: MediaQuery.textScalerOf(context),
                  ),
                ),
              ),
              SliverCrossAxisExpanded(
                flex: 1,
                sliver: SliverPadding(
                  padding: const EdgeInsets.only(right: 16),
                  sliver: SliverList.separated(
                    itemCount: dateGroup.sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, index) =>
                        SessionCard(data: dateGroup.sessions[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateIndicatorHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateIndicatorHeaderDelegate({
    required this.date,
    required this.isToday,
    required this.scaler,
  });

  final DateTime date;
  final bool isToday;
  final TextScaler scaler;

  @override
  double get minExtent => scaler.scale(DateIndicator._height);

  @override
  double get maxExtent => scaler.scale(DateIndicator._height);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: DateIndicator(date: date, isToday: isToday),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateIndicatorHeaderDelegate oldDelegate) {
    return date != oldDelegate.date || isToday != oldDelegate.isToday;
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

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _width,
        maxWidth: _width,
        minHeight: _height,
      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
        Column(
          mainAxisSize: MainAxisSize.min,
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
      ],
    );
  }
}
