import 'dart:math' as math;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/grounding_marquee.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/widgets/viewport_resolver.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({required this.event, super.key});

  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomStatus = ref.watch(roomStatusProvider);
    final amNext = ref.watch(amNextSpeakerProvider);
    final currentSession = ref.watch(currentSessionProvider)!;
    final currentSessionState = ref.watch(currentSessionStateProvider)!;
    final activeSpeaker = ref.watch(featuredParticipantProvider);
    final nextUp = ref.watch(speakingNextParticipantProvider);
    final hasKeeper = ref.watch(hasKeeperProvider);
    final isCurrentUserKeeper = ref.watch(isCurrentUserKeeperProvider);

    return RoomBackground(
      status: roomStatus,
      child: ViewportResolver(
        builder: (context, viewportKind) {
          final theme = Theme.of(context);
          final nextUpText = () {
            if (roomStatus == RoomStatus.waitingRoom) {
              return Text(
                () {
                  if (!hasKeeper) {
                    return 'Waiting for the Keeper to join...';
                  }
                  return 'The session is about to start...';
                }(),
                style: theme.textTheme.bodyLarge,
              );
            } else if (roomStatus == RoomStatus.active) {
              if (!hasKeeper) {
                return Text(
                  'The session has been paused...',
                  style: theme.textTheme.bodyLarge,
                );
              } else if (nextUp != null) {
                return RichText(
                  text: TextSpan(
                    children: [
                      if (amNext)
                        const TextSpan(
                          text: 'You are Next',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )
                      else ...[
                        const TextSpan(text: 'Next up '),
                        TextSpan(
                          text: nextUp.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              }
            }

            // Return a sized box because we want the spacing to remain consistent.
            return const SizedBox.shrink();
          }();

          final participantGrid = _NotMyTurnGrid(
            event: event,
            speakingNow: activeSpeaker?.identity,
            viewportKind: viewportKind,
          );

          final startCard = () {
            if (roomStatus == RoomStatus.waitingRoom && isCurrentUserKeeper) {
              return TransitionCard(
                type: TotemCardTransitionType.start,
                onActionPressed: currentSession.keeper.startSession,
              );
            }
            return null;
          }();

          final Widget? marqueeOrStart = () {
            if (roomStatus == RoomStatus.waitingRoom) {
              if (isCurrentUserKeeper) {
                return startCard;
              } else {
                return const GroundingMarquee();
              }
            }
          }();

          switch (viewportKind) {
            case ViewportKind.smallPortrait:
              return SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    SizedBox(
                      height: MediaQuery.heightOf(context) * 0.475,
                      child: const FeaturedParticipantCard(),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 28,
                      ),
                      child: nextUpText,
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 28,
                        ),
                        child: participantGrid,
                      ),
                    ),
                    ?marqueeOrStart,
                    const Center(child: SessionActionBar()),
                  ],
                ),
              );
            case ViewportKind.smallLandscape:
              final isLTR = Directionality.of(context) == TextDirection.ltr;
              return SafeArea(
                top: false,
                bottom: false,
                left: !isLTR,
                right: isLTR,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(flex: 2, child: FeaturedParticipantCard()),
                    Expanded(
                      flex: 3,
                      child: SafeArea(
                        left: false,
                        right: true,
                        child: Overlay.wrap(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 16,
                              top: 16,
                            ),
                            child: Column(
                              spacing: 16,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                nextUpText,
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.symmetric(
                                          vertical: 8,
                                        ),
                                    child: participantGrid,
                                  ),
                                ),
                                ?marqueeOrStart,
                                const Center(
                                  child: SessionActionBar(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            case ViewportKind.mediumPlus:
              final participantKeys = ref.watch(sessionParticipantKeysProvider);
              return Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                child: Column(
                  spacing: 10,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 20.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${currentSessionState.participants.participants.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: ' Participants'),
                                ],
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                Text(
                                  event.title,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  event.space.title,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (roomStatus == RoomStatus.active)
                            Expanded(
                              child: Column(
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: activeSpeaker?.name ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const TextSpan(text: ' Now speaking'),
                                      ],
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        if (amNext)
                                          const TextSpan(
                                            text: 'You are Next',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        else if (nextUp != null) ...[
                                          const TextSpan(text: 'Next up '),
                                          TextSpan(
                                            text: nextUp.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ],
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            const Spacer(),
                        ],
                      ),
                    ),
                    Divider(
                      color: switch (roomStatus) {
                        RoomStatus.waitingRoom => AppTheme.slate,
                        _ => AppTheme.cream,
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(10.0),
                        child: Column(
                          spacing: 10,
                          children: [
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Row(
                                  spacing: 20,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // TODO(web): The featured card should have the same height as the grid
                                    // Currently, when there are 5 participants, for example, the grid is at
                                    // the middle of the tile, causing a weird effect.
                                    if (roomStatus == RoomStatus.active &&
                                        activeSpeaker != null)
                                      ParticipantCard(
                                        key: participantKeys.getKey(
                                          activeSpeaker.identity,
                                        ),
                                        session: event,
                                        participant: activeSpeaker,
                                        participantIdentity:
                                            activeSpeaker.identity,
                                      ),
                                    Flexible(
                                      child: _NotMyTurnGrid(
                                        event: event,
                                        speakingNow: activeSpeaker?.identity,
                                        // Only show the speaking now participant in waiting room.
                                        // In active room, the speaking now participant is already featured.
                                        showSpeakingNowParticipant:
                                            roomStatus ==
                                            RoomStatus.waitingRoom,
                                        gap: 20,
                                        viewportKind: viewportKind,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (roomStatus == RoomStatus.waitingRoom) ...[
                              const GroundingMarquee(),
                              ?startCard,
                            ],
                            const Center(child: SessionActionBar()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}

class _NotMyTurnGrid extends ConsumerWidget {
  const _NotMyTurnGrid({
    required this.event,
    required this.speakingNow,
    required this.viewportKind,
    this.showSpeakingNowParticipant = false,
    this.gap = 10,
  });

  final SessionDetailSchema event;
  final String? speakingNow;
  final bool showSpeakingNowParticipant;
  final double gap;
  final ViewportKind viewportKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantKeys = ref.watch(sessionParticipantKeysProvider);
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticipants: participants,
      state: sessionState,
      speakingNow: speakingNow,
      showSpeakingNow: showSpeakingNowParticipant,
    );
    final itemCount = sortedParticipants.length;
    if (itemCount == 0) return const SizedBox.shrink();

    late final int crossAxisCount;
    switch (viewportKind) {
      case ViewportKind.smallPortrait:
        if (itemCount <= 6) {
          crossAxisCount = 3;
        } else if (itemCount <= 12) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 5;
        }
      case ViewportKind.smallLandscape:
        if (itemCount <= 2) {
          crossAxisCount = 2;
        } else if (itemCount <= 4) {
          crossAxisCount = 2;
        } else if (itemCount <= 6) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }
      case ViewportKind.mediumPlus:
        if (itemCount <= 2) {
          crossAxisCount = 1;
        } else if (itemCount <= 4) {
          crossAxisCount = 2;
        } else if (itemCount <= 8) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = math.sqrt(itemCount).ceil();
        }
    }

    final rowCount = (itemCount / crossAxisCount).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: List.generate(
        rowCount,
        (rowIndex) {
          final startIndex = rowIndex * crossAxisCount;

          return Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: gap,
              children: List.generate(
                crossAxisCount,
                (colIndex) {
                  final itemIndex = startIndex + colIndex;
                  if (itemIndex < itemCount) {
                    final participant = sortedParticipants[itemIndex];
                    return Expanded(
                      child: ParticipantCard(
                        key: participantKeys.getKey(participant.identity),
                        participant: participant,
                        session: event,
                        participantIdentity: participant.identity,
                      ),
                    );
                  } else {
                    return const Expanded(child: SizedBox.shrink());
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
