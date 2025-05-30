import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:totem_app/api/models/event_detail_schema.dart';

class SpaceJoinCard extends StatelessWidget {
  const SpaceJoinCard({required this.event, super.key});

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dateFormatter = DateFormat('E MMM dd');
    final timeFormatter = DateFormat('hh:mm a');

    final hasStarted =
        event.start.isBefore(DateTime.now()) &&
        event.start
            .add(Duration(minutes: event.duration))
            .isAfter(DateTime.now());

    final hasEnded = event.start
        .add(Duration(minutes: event.duration))
        .isBefore(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 20,
          end: 10,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    () {
                      if (hasStarted) return 'Session Started';
                      if (hasEnded) return 'Session Ended';

                      final isToday =
                          DateTime.now().day == event.start.day &&
                          DateTime.now().month == event.start.month &&
                          DateTime.now().year == event.start.year;
                      if (isToday) return 'Today';
                      return dateFormatter.format(event.start);
                    }(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 0.8,
                    ),
                  ),
                  Text(() {
                    if (hasStarted) return timeago.format(event.start);
                    if (hasEnded) return 'Explore upcoming session';

                    return timeFormatter.format(event.start);
                  }(), style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 115),
              child: ElevatedButton(
                onPressed: () {
                  // TODO(bdlukaa): Implement join space functionality
                },
                child: Text(
                  () {
                    if (hasStarted) return 'Join Now';
                    if (hasEnded) return 'Explore';
                    return 'Join';
                  }(),
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
