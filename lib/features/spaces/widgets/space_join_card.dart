import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/meeting_provider_enum.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/calendar_service.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

enum SpaceJoinCardState {
  ended,
  cancelled,
  closed,
  joinable,
  full,
  joined,
  notJoined,
}

class SpaceJoinCard extends ConsumerStatefulWidget {
  const SpaceJoinCard({required this.space, required this.event, super.key});

  final SpaceDetailSchema space;
  final EventDetailSchema event;

  @override
  ConsumerState<SpaceJoinCard> createState() => _SpaceJoinCardState();
}

class _SpaceJoinCardState extends ConsumerState<SpaceJoinCard> {
  EventDetailSchema get event => widget.event;

  late bool _attending = event.attending;
  var _loading = false;

  // Refresh every second to update timeago and button states
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasStarted =
        event.start.isBefore(DateTime.now()) &&
        event.start
            .add(Duration(minutes: event.duration))
            .isAfter(DateTime.now());

    final hasEnded = event.start
        .add(Duration(minutes: event.duration))
        .isBefore(DateTime.now());

    return SafeArea(
      top: false,
      child: Card(
        elevation: 10,
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
                            return 'No more upcoming sessions';
                          case SpaceJoinCardState.cancelled:
                            return 'This session has been cancelled';
                          case SpaceJoinCardState.joinable:
                            return 'Session Started';
                          case SpaceJoinCardState.closed:
                            return 'This session is closed';
                          case SpaceJoinCardState.full:
                            return 'This session is full';
                          case SpaceJoinCardState.joined:
                          case SpaceJoinCardState.notJoined:
                            return formatEventDate(event.start);
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
                            return formatEventTime(
                              event.start,
                              // widget.event.userTimezone,
                            );
                          case SpaceJoinCardState.joinable:
                            return timeago.format(event.start);
                          case SpaceJoinCardState.ended:
                          case SpaceJoinCardState.cancelled:
                          case SpaceJoinCardState.closed:
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
                      : hasStarted &&
                            event.meetingProvider ==
                                MeetingProviderEnum.googleMeet
                      ? Uri.parse(getFullUrl(event.calLink))
                      : null,
                  builder: (context, followLink) {
                    const secondaryButtonStyle = ButtonStyle(
                      padding: WidgetStatePropertyAll(
                        EdgeInsetsDirectional.zero,
                      ),
                      maximumSize: WidgetStatePropertyAll(Size.square(46)),
                      minimumSize: WidgetStatePropertyAll(Size.square(46)),
                      foregroundColor: WidgetStatePropertyAll(
                        AppTheme.mauve,
                      ),
                    );
                    if (state == SpaceJoinCardState.joined) {
                      return SizedBox(
                        height: 46,
                        child: Row(
                          spacing: 14,
                          children: [
                            Semantics(
                              label: 'Add session to calendar',
                              button: true,
                              child: Tooltip(
                                message: 'Add to calendar',
                                child: OutlinedButton(
                                  onPressed: addToCalendar,
                                  style: secondaryButtonStyle,
                                  child: const TotemIcon(
                                    TotemIcons.calendar,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            Semantics(
                              label: 'Give up your spot in this session',
                              button: true,
                              enabled: !_loading,
                              child: Tooltip(
                                message: 'Give up your spot',
                                child: OutlinedButton(
                                  onPressed: _loading ? null : giveUpSpot,
                                  style: secondaryButtonStyle,
                                  child: _loading
                                      ? const LoadingIndicator(size: 24)
                                      : const TotemIcon(
                                          TotemIcons.giveUpSpot,
                                          size: 24,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    void onPressed() {
                      switch (state) {
                        case SpaceJoinCardState.ended:
                        case SpaceJoinCardState.cancelled:
                        case SpaceJoinCardState.closed:
                          toHome(HomeRoutes.spaces);
                        case SpaceJoinCardState.joinable:
                          if (event.meetingProvider ==
                              MeetingProviderEnum.livekit) {
                            unawaited(joinLivekit());
                          } else {
                            unawaited(followLink?.call());
                          }
                        case SpaceJoinCardState.joined:
                          unawaited(addToCalendar());
                        case SpaceJoinCardState.full:
                          toHome(HomeRoutes.spaces);
                        case SpaceJoinCardState.notJoined:
                          unawaited(attend(ref));
                      }
                    }

                    final content = Center(
                      child: Text(
                        switch (state) {
                          SpaceJoinCardState.ended ||
                          SpaceJoinCardState.cancelled ||
                          SpaceJoinCardState.closed => 'Explore',
                          SpaceJoinCardState.joinable => 'Join Now',
                          SpaceJoinCardState.joined => 'Add to calendar',
                          SpaceJoinCardState.full => 'Explore',
                          SpaceJoinCardState.notJoined => 'Attend',
                        },
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    );

                    switch (state) {
                      case SpaceJoinCardState.closed:
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 14,
                          children: [
                            if (_attending)
                              Tooltip(
                                message: 'Give up your spot',
                                child: OutlinedButton(
                                  onPressed: _loading ? null : giveUpSpot,
                                  style: secondaryButtonStyle,
                                  child: const TotemIcon(
                                    TotemIcons.giveUpSpot,
                                    size: 24,
                                  ),
                                ),
                              ),
                            OutlinedButton(
                              style: secondaryButtonStyle,
                              onPressed: onPressed,
                              child: _loading
                                  ? const LoadingIndicator(size: 24)
                                  : content,
                            ),
                          ],
                        );
                      case SpaceJoinCardState.ended:
                      case SpaceJoinCardState.cancelled:
                      case SpaceJoinCardState.joined:
                      case SpaceJoinCardState.full:
                        return OutlinedButton(
                          onPressed: onPressed,
                          child: _loading
                              ? const LoadingIndicator(size: 24)
                              : content,
                        );
                      case SpaceJoinCardState.joinable:
                      case SpaceJoinCardState.notJoined:
                        return ElevatedButton(
                          onPressed: onPressed,
                          style: ElevatedButton.styleFrom(
                            maximumSize: const Size(156, 46),
                            minimumSize: const Size(46, 46),
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 22,
                            ),
                            backgroundColor: AppTheme.mauve,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: _loading
                              ? const LoadingIndicator(
                                  color: Colors.white,
                                  size: 24,
                                )
                              : content,
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
    if (event.cancelled) return SpaceJoinCardState.cancelled;

    final hasEnded = event.start
        .add(Duration(minutes: event.duration))
        .isBefore(DateTime.now());

    if (hasEnded) return SpaceJoinCardState.ended;

    final hasStarted =
        event.start.isBefore(DateTime.now()) &&
        event.start
            .add(Duration(minutes: event.duration))
            .isAfter(DateTime.now());

    if (hasStarted && event.joinable) {
      return SpaceJoinCardState.joinable;
    } else if (_attending) {
      return SpaceJoinCardState.joined;
    } else if (event.seatsLeft <= 0) {
      return SpaceJoinCardState.full;
    } else if (!event.open) {
      return SpaceJoinCardState.closed;
    } else {
      return SpaceJoinCardState.notJoined;
    }
  }

  Future<void> attend(WidgetRef ref) async {
    if (_attending ||
        _loading ||
        (kDebugMode && AppConfig.isProduction) ||
        !mounted) {
      return;
    }

    setState(() => _loading = true);

    try {
      final mobileApiService = ref.read(mobileApiServiceProvider);
      final response = await mobileApiService.spaces
          .totemCirclesMobileApiRsvpConfirm(eventSlug: event.slug);

      if (mounted) {
        setState(() => _loading = false);
      }

      if (response.attending) {
        if (mounted) {
          setState(() => _attending = true);
          unawaited(attendingPopup());
        }
        await refresh();
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
    } catch (e) {
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

  Future<void> attendingPopup() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AttendingDialog(
          eventSlug: event.slug,
          onAddToCalendar: addToCalendar,
        );
      },
    );

    double randomInRange(double min, double max) {
      return min + Random().nextDouble() * (max - min);
    }

    const total = 10;
    var progress = 0;

    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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

  Future<void> addToCalendar() async {
    // Create the calendar event with session details
    final calendarEvent = AppCalendarEvent(
      title: widget.space.title,
      description: widget.space.shortDescription,
      location: getFullUrl(event.calLink),
      start: event.start.toLocal(),
      end: event.start.add(Duration(minutes: event.duration)).toLocal(),
      reminderMinutesBefore: 15,
    );

    try {
      // Attempt to add the event to the device calendar
      final success = await CalendarService.addToCalendar(calendarEvent);

      if (!success) {
        // If the user cancelled or the native calendar failed,
        if (mounted) {
          showErrorPopup(
            context,
            icon: TotemIcons.calendar,
            title: 'Failed to add event to calendar',
            message: 'Please try again later',
          );
        }
      }
    } catch (error, _) {
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.calendar,
          title: 'Failed to add event to calendar',
          message: 'Please try again later',
        );
      }
    }
  }

  Future<void> giveUpSpot() async {
    final giveUp = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ConfirmationDialog(
          content: 'Are you sure you want to give up your spot?',
          confirmButtonText: 'Give up my spot',
          onConfirm: () async {
            Navigator.of(context).pop(true);
          },
        );
      },
    );

    if (giveUp == null || !giveUp || !mounted) return;

    setState(() => _loading = true);

    try {
      final mobileApiService = ref.read(mobileApiServiceProvider);
      final response = await mobileApiService.spaces
          .totemCirclesMobileApiRsvpCancel(eventSlug: event.slug);

      if (mounted) {
        setState(() => _loading = false);
      }

      if (!response.attending) {
        if (mounted) {
          setState(() => _attending = false);
          showErrorPopup(
            context,
            icon: TotemIcons.seats,
            title: 'You gave up your spot',
            message: 'You can always attend again if a spot opens up.',
          );
        }
        await refresh();
      } else {
        if (mounted) {
          showErrorPopup(
            context,
            icon: TotemIcons.seats,
            title: 'Failed to give up your spot',
            message: 'Please try again later',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.seats,
          title: 'Failed to give up your spot',
          message: 'Please try again later',
        );
      }
    }
  }

  Future<void> refresh() async {
    // We still want to wait for the refresh to complete
    // ignore: unused_result
    await ref.refresh(eventProvider(event.slug).future);
    // We still want to wait for the refresh to complete
    // ignore: unused_result
    await ref.refresh(spaceProvider(widget.space.slug).future);
  }

  Future<void> joinLivekit() async {
    debugPrint('Joining livekit');
    await context.pushNamed(RouteNames.videoSessionPrejoin, extra: event.slug);
  }
}

class AttendingDialog extends StatefulWidget {
  const AttendingDialog({
    required this.onAddToCalendar,
    required this.eventSlug,
    super.key,
  });

  final String eventSlug;
  final VoidCallback onAddToCalendar;

  @override
  State<AttendingDialog> createState() => _AttendingDialogState();
}

class _AttendingDialogState extends State<AttendingDialog> {
  var _addedToCalendar = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) {
                    return Container(
                      height: 30,
                      width: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Semantics(
                        label: 'Share this session',
                        button: true,
                        child: IconButton(
                          padding: EdgeInsetsDirectional.zero,
                          iconSize: 18,
                          color: const Color(0xFF787D7E),
                          onPressed: () async {
                            final box =
                                context.findRenderObject() as RenderBox?;
                            await SharePlus.instance.share(
                              ShareParams(
                                uri: Uri.parse(AppConfig.mobileApiUrl)
                                    .resolve(
                                      '/spaces/event/${widget.eventSlug}',
                                    )
                                    .resolve(
                                      '?utm_source=app&utm_medium=share',
                                    ),
                                sharePositionOrigin: box != null
                                    ? box.localToGlobal(
                                            Offset.zero,
                                          ) &
                                          box.size
                                    : null,
                              ),
                            );
                          },
                          icon: Icon(Icons.adaptive.share),
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                Container(
                  height: 30,
                  width: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Semantics(
                    label: 'Close dialog',
                    button: true,
                    child: IconButton(
                      padding: EdgeInsetsDirectional.zero,
                      iconSize: 18,
                      color: const Color(0xFF787D7E),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
            const TotemIcon(
              TotemIcons.greenCheckbox,
              size: 95,
              color: Color(0xFF98BD44),
            ),
            Text(
              "You're going!",
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text:
                        "We'll send you a notification before the session "
                        'starts.',
                  ),
                  TextSpan(text: '\n\n'),
                  TextSpan(
                    text:
                        'When you join, you’ll be in a Space where we take '
                        'turns speaking while holding the virtual Totem — '
                        'feel free to share when it’s your turn, or simply '
                        'listen if you prefer.',
                  ),
                  TextSpan(text: '\n\n'),
                  TextSpan(
                    text: 'Totem is better with friends!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        " Share this link with your friends and they'll be "
                        'able to join as well.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () {
                if (!_addedToCalendar) {
                  widget.onAddToCalendar();
                  setState(() => _addedToCalendar = true);
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Text(_addedToCalendar ? 'Added!' : 'Add to Calendar'),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'In the meantime, review our ',
                  ),
                  TextSpan(
                    text: 'Community Guidelines',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          launchUrl(AppConfig.communityGuidelinesUrl),
                  ),
                  const TextSpan(
                    text: ' to learn more about how to participate.',
                  ),
                ],
              ),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
