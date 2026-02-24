import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/profile/screens/user_feedback.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SessionDisconnectedReason {
  /// The session has ended normally, usually by the keeper.
  keeperEnded,

  /// The keeper left the session and didn't come back within the timeout period.
  keeperAbsent,

  /// The keeper never joined the session and it ended after the timeout period.
  roomEmpty,

  /// The user was kicked out of the session by the keeper.
  removed,
}

class SessionDisconnectedScreen extends ConsumerStatefulWidget {
  const SessionDisconnectedScreen({required this.session, super.key});

  final SessionDetailSchema session;

  @override
  ConsumerState<SessionDisconnectedScreen> createState() =>
      _SessionDisconnectedScreenState();

  static const _reviewRequestedKey = 'session_review_requested';
  static const _sessionLikedCountKey = 'session_liked_count';
}

class _SessionDisconnectedScreenState
    extends ConsumerState<SessionDisconnectedScreen> {
  ThumbState _thumbState = ThumbState.none;
  Timer? _confettiTimer;

  void _showConfetti() {
    double randomInRange(double min, double max) {
      return min + Random().nextDouble() * (max - min);
    }

    const total = 10;
    var progress = 0;
    _confettiTimer?.cancel();
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        _confettiTimer = null;
        return;
      }
      progress++;

      if (progress >= total) {
        timer.cancel();
        _confettiTimer = null;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.context.mounted) ref.invalidate(spacesSummaryProvider);
    });
    // 2.75 seconds later, refresh spaces summary again to ensure data is up to date.
    Future.delayed(const Duration(milliseconds: 2750), () {
      if (ref.context.mounted) ref.invalidate(spacesSummaryProvider);
    });
  }

  @override
  void dispose() {
    _confettiTimer?.cancel();
    _confettiTimer = null;
    super.dispose();
  }

  void refresh() {
    ref
      ..invalidate(spacesSummaryProvider)
      ..invalidate(sessionTokenProvider(widget.session.slug))
      ..invalidate(eventProvider(widget.session.slug));
  }

  @override
  Widget build(BuildContext context) {
    // TODO(bdlukaa): Implement a landscape version of this screen.
    final theme = Theme.of(context);
    final recommended = ref.watch(getRecommendedSessionsProvider());
    final sessionReason = ref.watch(
      currentSessionStateProvider.select((s) {
        if (s?.roomState.status == RoomStatus.ended &&
            s?.roomState.statusDetail
                is RoomStateStatusDetailSealedEndedDetail) {
          final detail =
              s!.roomState.statusDetail
                  as RoomStateStatusDetailSealedEndedDetail;
          return switch (detail.reason) {
            EndReason.keeperAbsent => _SessionDisconnectedReason.keeperAbsent,
            EndReason.roomEmpty => _SessionDisconnectedReason.roomEmpty,
            EndReason.keeperEnded ||
            EndReason.$unknown => _SessionDisconnectedReason.keeperEnded,
          };
        }
      }),
    );

    final nextEvents = widget.session.space.nextEvents
        .where((e) => e.slug != widget.session.slug)
        .take(2)
        .toList();

    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Semantics(
                header: true,
                child: Text(
                  switch (sessionReason) {
                    _SessionDisconnectedReason.keeperAbsent =>
                      'Session will be rescheduled',
                    _SessionDisconnectedReason.removed =>
                      'You’ve been removed from this session.',
                    _SessionDisconnectedReason.keeperEnded ||
                    _ => 'Session Ended',
                  },
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Text.rich(
                switch (sessionReason) {
                  _SessionDisconnectedReason.keeperAbsent => const TextSpan(
                    text:
                        'The session ended due to technical difficulties and couldn’t continue. We’ll notify you when it’s rescheduled.',
                  ),
                  _SessionDisconnectedReason.removed => TextSpan(
                    text: 'Please take a moment to review our ',
                    children: [
                      TextSpan(
                        text: 'Community Guidelines',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            context.push(RouteNames.communityGuidelines);
                          },
                      ),
                      const TextSpan(text: '. '),
                      const TextSpan(
                        text:
                            'If you believe this was a mistake, reach out to us at ',
                      ),
                      TextSpan(
                        text: 'help@totem.org',
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            launchUrl(Uri.parse('mailto:help@totem.org'));
                          },
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  _SessionDisconnectedReason.keeperEnded || _ => const TextSpan(
                    text:
                        'Thank you for joining!\nWe hope you found the session enjoyable.',
                  ),
                },
                textAlign: TextAlign.center,
              ),
              if (sessionReason == _SessionDisconnectedReason.keeperEnded) ...[
                _SessionFeedbackWidget(
                  state: _thumbState,
                  onThumbUpPressed: () async {
                    setState(() => _thumbState = ThumbState.up);
                    _showConfetti();
                    await ref.read(
                      sessionFeedbackProvider(
                        widget.session.slug,
                        SessionFeedbackOptions.up,
                      ).future,
                    );
                    await _incrementSessionLikedCount();
                  },
                  onThumbDownPressed: () async {
                    await showUserFeedbackDialog(
                      context,
                      onFeedbackSubmitted: (message) {
                        _thumbState = ThumbState.down;
                        if (mounted) setState(() {});
                        return ref.read(
                          sessionFeedbackProvider(
                            widget.session.slug,
                            SessionFeedbackOptions.down,
                            message,
                          ).future,
                        );
                      },
                    );
                  },
                ),
              ],

              if (nextEvents.isNotEmpty) ...[
                Text(
                  nextEvents.length == 1
                      ? 'Join this upcoming session'
                      : 'Join these upcoming sessions',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.start,
                ),
                for (final nextEvent in nextEvents)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 140,
                      ),
                      child: SmallSpaceCard(
                        space: MobileSpaceDetailSchemaExtension.copyWith(
                          widget.session.space,
                          nextEvents: [nextEvent],
                        ),
                        onTap: () {
                          refresh();
                          return context.pushReplacement(
                            RouteNames.spaceSession(
                              widget.session.space.slug,
                              nextEvent.slug,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ] else
                ...recommended.when(
                  data: (data) sync* {
                    if (data.isNotEmpty) {
                      yield Text(
                        'You may enjoy these spaces',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.start,
                      );
                      for (final event in data.take(2)) {
                        yield Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 140,
                            ),
                            child: SmallSpaceCard.fromSessionDetailSchema(
                              event,
                              onTap: () {
                                refresh();
                                return context.pushReplacement(
                                  RouteNames.space(event.space.slug),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    }
                  },
                  error: (error, _) => [],
                  loading: () => [],
                ),
              ElevatedButton(
                onPressed: () {
                  refresh();
                  toHome(HomeRoutes.initialRoute);
                },
                child: const Text('Explore More'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _incrementSessionLikedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested =
        prefs.getBool(SessionDisconnectedScreen._reviewRequestedKey) ?? false;
    if (alreadyRequested) return;

    final count =
        (prefs.getInt(SessionDisconnectedScreen._sessionLikedCountKey) ?? 0) +
        1;
    await prefs.setInt(SessionDisconnectedScreen._sessionLikedCountKey, count);
    if (count >= 5) {
      final inAppReview = InAppReview.instance;
      try {
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          await prefs.setBool(
            SessionDisconnectedScreen._reviewRequestedKey,
            true,
          );
        }
      } catch (_) {
        // Fine if fail
      }
    }
  }
}

enum ThumbState { up, down, none }

class _SessionFeedbackWidget extends StatelessWidget {
  const _SessionFeedbackWidget({
    required this.state,
    required this.onThumbUpPressed,
    required this.onThumbDownPressed,
  });

  final ThumbState state;
  final VoidCallback onThumbUpPressed;
  final VoidCallback onThumbDownPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Flexible(
            fit: switch (state) {
              ThumbState.up => FlexFit.tight,
              ThumbState.down => FlexFit.tight,
              ThumbState.none => FlexFit.loose,
            },
            child: AutoSizeText(
              switch (state) {
                ThumbState.none => 'How was your experience?',
                _ => 'Thank you for your feedback!',
              },
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (state == ThumbState.none)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 10,
                children: [
                  _SessionFeedbackButton(
                    icon: const TotemIcon(TotemIcons.thumbUp),
                    onPressed: switch (state) {
                      ThumbState.up => () {},
                      _ => onThumbUpPressed,
                    },
                  ),
                  _SessionFeedbackButton(
                    icon: const TotemIcon(TotemIcons.thumbDown),
                    onPressed: switch (state) {
                      ThumbState.down => () {},
                      _ => onThumbDownPressed,
                    },
                  ),
                ],
              ),
            )
          else
            IgnorePointer(
              child: _SessionFeedbackButton(
                outlined: true,
                icon: TotemIcon(
                  switch (state) {
                    ThumbState.up => TotemIcons.thumbUpFilled,
                    ThumbState.down => TotemIcons.thumbDownFilled,
                    _ => TotemIcons.thumbUp,
                  },
                ),
                onPressed: () {},
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionFeedbackButton extends StatelessWidget {
  const _SessionFeedbackButton({
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final Widget icon;
  final VoidCallback onPressed;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsetsDirectional.all(10),
        decoration: BoxDecoration(
          color: outlined ? null : theme.colorScheme.primary,
          border: outlined
              ? Border.all(color: theme.colorScheme.primary)
              : null,
          shape: BoxShape.circle,
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            color: outlined
                ? theme.colorScheme.primary
                : theme.colorScheme.onPrimary,
          ),
          child: icon,
        ),
      ),
    );
  }
}
