import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/network.dart';
import 'package:url_launcher/link.dart';

enum SpaceJoinCardState {
  ended,
  cancelled,
  joinable,
  closedToNewParticipants,
  full,
  joined,
  notJoined,
}

class SpaceJoinCard extends ConsumerStatefulWidget {
  const SpaceJoinCard({required this.event, super.key});

  final EventDetailSchema event;

  @override
  ConsumerState<SpaceJoinCard> createState() => _SpaceJoinCardState();
}

class _SpaceJoinCardState extends ConsumerState<SpaceJoinCard> {
  late bool _attending = widget.event.attending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dateFormatter = DateFormat('EEEE, MMMM dd');
    final timeFormatter = DateFormat('hh:mm a');

    final hasStarted =
        widget.event.start.isBefore(DateTime.now()) &&
        widget.event.start
            .add(Duration(minutes: widget.event.duration))
            .isAfter(DateTime.now());

    final hasEnded = widget.event.start
        .add(Duration(minutes: widget.event.duration))
        .isBefore(DateTime.now());

    return SafeArea(
      top: false,
      child: Card(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      () {
                        switch (state) {
                          case SpaceJoinCardState.ended:
                            return 'Session Ended';
                          case SpaceJoinCardState.cancelled:
                            return 'This session has been cancelled';
                          case SpaceJoinCardState.joinable:
                            return 'Session Started';
                          case SpaceJoinCardState.closedToNewParticipants:
                            return 'This session is closed for new '
                                'participants';
                          case SpaceJoinCardState.full:
                            return 'This session is full';
                          case SpaceJoinCardState.joined:
                          case SpaceJoinCardState.notJoined:
                            final isToday =
                                DateTime.now().day == widget.event.start.day &&
                                DateTime.now().month ==
                                    widget.event.start.month &&
                                DateTime.now().year == widget.event.start.year;
                            if (isToday) return 'Today';
                            return dateFormatter.format(widget.event.start);
                        }
                      }(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      () {
                        switch (state) {
                          case SpaceJoinCardState.joined:
                          case SpaceJoinCardState.notJoined:
                            return '${timeFormatter.format(widget.event.start)}'
                                    ' ${widget.event.userTimezone ?? ''}'
                                .trim();
                          case SpaceJoinCardState.joinable:
                            return timeago.format(widget.event.start);
                          case SpaceJoinCardState.ended:
                          case SpaceJoinCardState.cancelled:
                          case SpaceJoinCardState.closedToNewParticipants:
                          case SpaceJoinCardState.full:
                            return 'Explore upcoming sessions';
                        }
                      }(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 115),
                child: Link(
                  uri: hasEnded
                      ? null
                      : hasStarted
                      ? Uri.parse(getFullUrl(widget.event.calLink))
                      : null,
                  builder: (context, followLink) {
                    return ElevatedButton(
                      onPressed: () {
                        switch (state) {
                          case SpaceJoinCardState.ended:
                          case SpaceJoinCardState.cancelled:
                          case SpaceJoinCardState.closedToNewParticipants:
                            toHome(HomeRoutes.spaces);
                          case SpaceJoinCardState.joinable:
                            followLink?.call();
                          case SpaceJoinCardState.joined:
                            addToCalendar();
                          case SpaceJoinCardState.full:
                            toHome(HomeRoutes.spaces);
                          case SpaceJoinCardState.notJoined:
                            attend(ref);
                        }
                      },
                      child: Text(
                        switch (state) {
                          SpaceJoinCardState.ended ||
                          SpaceJoinCardState.cancelled ||
                          SpaceJoinCardState.closedToNewParticipants =>
                            'Explore',
                          SpaceJoinCardState.joinable => 'Join Now',
                          SpaceJoinCardState.joined => 'Add to calendar',
                          SpaceJoinCardState.full => 'Explore',
                          SpaceJoinCardState.notJoined => 'Attend',
                        },
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SpaceJoinCardState get state {
    if (widget.event.cancelled) return SpaceJoinCardState.cancelled;

    final hasStarted =
        widget.event.start.isBefore(DateTime.now()) &&
        widget.event.start
            .add(Duration(minutes: widget.event.duration))
            .isAfter(DateTime.now());

    final hasEnded = widget.event.start
        .add(Duration(minutes: widget.event.duration))
        .isBefore(DateTime.now());

    if (hasEnded) {
      return SpaceJoinCardState.ended;
    } else if (hasStarted) {
      if (widget.event.joinable) {
        return SpaceJoinCardState.joinable;
      }
    } else {
      if (_attending) {
        return SpaceJoinCardState.joined;
      } else if (widget.event.seatsLeft <= 0) {
        return SpaceJoinCardState.full;
      }
    }
    return SpaceJoinCardState.notJoined;
  }

  Future<void> attend(WidgetRef ref) async {
    final mobileApiService = ref.read(mobileApiServiceProvider);
    final response = await mobileApiService.spaces
        .totemCirclesMobileApiRsvpConfirm(
          eventSlug: widget.event.slug,
        );

    if (response) {
      setState(() => _attending = true);
    }
  }

  void addToCalendar() {}
}
