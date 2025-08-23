import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
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
  var _loading = false;

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
                    void onPressed() {
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
                    }

                    final content = Text(
                      switch (state) {
                        SpaceJoinCardState.ended ||
                        SpaceJoinCardState.cancelled ||
                        SpaceJoinCardState.closedToNewParticipants => 'Explore',
                        SpaceJoinCardState.joinable => 'Join Now',
                        SpaceJoinCardState.joined => 'Add to calendar',
                        SpaceJoinCardState.full => 'Explore',
                        SpaceJoinCardState.notJoined => 'Attend',
                      },
                      style: const TextStyle(fontWeight: FontWeight.w400),
                    );

                    switch (state) {
                      case SpaceJoinCardState.ended:
                      case SpaceJoinCardState.cancelled:
                      case SpaceJoinCardState.closedToNewParticipants:
                      case SpaceJoinCardState.joined:
                      case SpaceJoinCardState.full:
                        return OutlinedButton(
                          onPressed: onPressed,
                          child: content,
                        );
                      case SpaceJoinCardState.joinable:
                      case SpaceJoinCardState.notJoined:
                        return ElevatedButton(
                          onPressed: onPressed,
                          child: content,
                        );
                    }
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
    if (_attending || _loading) return;

    _loading = true;

    final mobileApiService = ref.read(mobileApiServiceProvider);
    final response = await mobileApiService.spaces
        .totemCirclesMobileApiRsvpConfirm(
          eventSlug: widget.event.slug,
        );
    _loading = false;

    if (response) {
      setState(() => _attending = true);
      _emitFireworks();
    } else {
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.spaces,
          title: 'Failed to attend to this circle',
          message: 'Please try again later',
        );
      }
    }
  }

  void _emitFireworks() {
    double randomInRange(double min, double max) {
      return min + Random().nextDouble() * (max - min);
    }

    const total = 10;
    var progress = 0;

    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      progress++;

      if (progress >= total) {
        timer.cancel();
        return;
      }

      final count = ((1 - progress / total) * 50).toInt();

      Confetti.launch(
        context,
        options: ConfettiOptions(
          particleCount: count,
          startVelocity: 30,
          spread: 360,
          ticks: 60,
          x: randomInRange(0.1, 0.3),
          y: Random().nextDouble() - 0.2,
        ),
      );
      Confetti.launch(
        context,
        options: ConfettiOptions(
          particleCount: count,
          startVelocity: 30,
          spread: 360,
          ticks: 60,
          x: randomInRange(0.7, 0.9),
          y: Random().nextDouble() - 0.2,
        ),
      );
    });
  }

  void addToCalendar() {}
}
