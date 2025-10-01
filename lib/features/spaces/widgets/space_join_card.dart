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
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/features/profile/screens/delete_account.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
                            return formatEventDate(widget.event.start);
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
                              widget.event.start,
                              // widget.event.userTimezone,
                            );
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
                      : hasStarted &&
                            widget.event.meetingProvider ==
                                MeetingProviderEnum.googleMeet
                      ? Uri.parse(getFullUrl(widget.event.calLink))
                      : null,
                  builder: (context, followLink) {
                    if (state == SpaceJoinCardState.joined) {
                      const buttonStyle = ButtonStyle(
                        padding: WidgetStatePropertyAll(
                          EdgeInsetsDirectional.zero,
                        ),
                        maximumSize: WidgetStatePropertyAll(Size.square(46)),
                        minimumSize: WidgetStatePropertyAll(Size.square(46)),
                        foregroundColor: WidgetStatePropertyAll(
                          AppTheme.mauve,
                        ),
                      );
                      return SizedBox(
                        height: 46,
                        child: Row(
                          spacing: 14,
                          children: [
                            Tooltip(
                              message: 'Add to calendar',
                              child: OutlinedButton(
                                onPressed: addToCalendar,
                                style: buttonStyle,
                                child: const TotemIcon(
                                  TotemIcons.calendar,
                                  size: 24,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Give up your spot',
                              child: OutlinedButton(
                                onPressed: giveUpSpot,
                                style: buttonStyle,
                                child: const TotemIcon(
                                  TotemIcons.giveUpSpot,
                                  size: 24,
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
                        case SpaceJoinCardState.closedToNewParticipants:
                          toHome(HomeRoutes.spaces);
                        case SpaceJoinCardState.joinable:
                          if (widget.event.meetingProvider ==
                              MeetingProviderEnum.livekit) {
                            joinLivekit();
                          } else {
                            followLink?.call();
                          }
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
                          child: _loading
                              ? const LoadingIndicator(size: 24)
                              : content,
                        );
                      case SpaceJoinCardState.joinable:
                      case SpaceJoinCardState.notJoined:
                        return ElevatedButton(
                          onPressed: onPressed,
                          style: ElevatedButton.styleFrom(
                            maximumSize: const Size(156, 60),
                            padding: const EdgeInsets.symmetric(
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
    if (_attending || _loading || (kDebugMode && AppConfig.isProduction)) {
      return;
    }

    setState(() => _loading = true);

    final mobileApiService = ref.read(mobileApiServiceProvider);
    final response = await mobileApiService.spaces
        .totemCirclesMobileApiRsvpConfirm(
          eventSlug: widget.event.slug,
        );

    setState(() => _loading = false);

    if (response) {
      setState(() => _attending = true);
      attendingPopup();
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

  void attendingPopup() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AttendingDialog(
          event: widget.event,
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
    // TODO(bdlukaa): Integrate this to the phone device
    // try {
    //   final eventide = Eventide();
    //   await eventide.createEventInDefaultCalendar(
    //     title: widget.event.space.title,
    //     // description: widget.event.space.shortDescription,
    //     startDate: widget.event.start.toLocal(),
    //     endDate: widget.event.start
    //         .add(Duration(minutes: widget.event.duration))
    //         .toLocal(),
    //     url: getFullUrl(widget.event.calLink),
    //     reminders: [
    //       const Duration(minutes: 30),
    //       const Duration(minutes: 15),
    //     ],
    //   );
    // } catch (error, stacktrace) {
    //   debugPrint('Failed to add event to calendar: $error\n$stacktrace');
    await launchUrlString(
      _buildGoogleCalendarUrl(
        title: widget.event.space.title,
        start: widget.event.start.toLocal(),
        end: widget.event.start
            .add(Duration(minutes: widget.event.duration))
            .toLocal(),
        description: widget.event.space.shortDescription,
      ),
    );
    // }
  }

  String _buildGoogleCalendarUrl({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
  }) {
    String formatDate(DateTime dt) {
      final iso = dt
          .toUtc()
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .split('.')
          .first;
      return '${iso}Z';
    }

    final startUtc = formatDate(start);
    final endUtc = formatDate(end);

    final Uri url = Uri.parse('https://calendar.google.com/calendar/render')
        .replace(
          queryParameters: {
            'action': 'TEMPLATE',
            'text': title,
            'dates': '$startUtc/$endUtc',
            if (description != null) 'details': description,
            if (location != null) 'location': location,
          },
        );

    return url.toString();
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

    if (giveUp == null || !giveUp) return;

    setState(() {
      _loading = true;
    });

    final mobileApiService = ref.read(mobileApiServiceProvider);
    final response = await mobileApiService.spaces
        .totemCirclesMobileApiRsvpCancel(
          eventSlug: widget.event.slug,
        );

    setState(() => _loading = false);

    if (response) {
      if (mounted) {
        setState(() => _attending = false);
        showErrorPopup(
          context,
          icon: TotemIcons.seats,
          title: 'You gave up your spot',
          message: 'You can always attend again if a spot opens up.',
        );
      }
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
  }

  Future<void> joinLivekit() async {
    debugPrint('Joining livekit');
    context.goNamed(RouteNames.videoSessionPrejoin, extra: widget.event);
  }
}

class AttendingDialog extends StatefulWidget {
  const AttendingDialog({
    required this.onAddToCalendar,
    required this.event,
    super.key,
  });

  final EventDetailSchema event;
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
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        color: const Color(0xFF787D7E),
                        onPressed: () {
                          final box = context.findRenderObject() as RenderBox?;
                          SharePlus.instance.share(
                            ShareParams(
                              uri: Uri.parse(AppConfig.mobileApiUrl)
                                  .resolve('/spaces/event/${widget.event.slug}')
                                  .resolve('?utm_source=app&utm_medium=share'),
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
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    color: const Color(0xFF787D7E),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
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
                      ..onTap = () {
                        launchUrl(AppConfig.communityGuidelinesUrl);
                      },
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
