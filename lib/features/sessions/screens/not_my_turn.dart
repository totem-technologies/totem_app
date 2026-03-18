// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/grounding_marquee.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({
    required this.actionBar,
    required this.event,
    super.key,
  });

  final Widget actionBar;
  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatus = ref.watch(roomStatusProvider);
    final amNext = ref.watch(amNextSpeakerProvider);
    final session = ref.watch(currentSessionStateProvider)!;
    final currentSession = ref.watch(currentSessionProvider)!;

    final activeSpeaker = session.featuredParticipant();

    return RoomBackground(
      status: sessionStatus,
      child: OrientationBuilder(
        builder: (context, orientation) {
          final theme = Theme.of(context);
          final isLandscape = orientation == Orientation.landscape;

          final nextUp = session.speakingNextParticipant();
          final nextUpText = () {
            if (sessionStatus == RoomStatus.waitingRoom) {
              return Text(
                () {
                  if (!session.hasKeeper) {
                    return 'Waiting for the Keeper to join...';
                  }
                  return 'The session is about to start...';
                }(),
                style: theme.textTheme.bodyLarge,
              );
            } else if (sessionStatus == RoomStatus.active) {
              if (!session.hasKeeper) {
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
            isLandscape: isLandscape,
          );

          final Widget? marquee = () {
            if (sessionStatus == RoomStatus.waitingRoom) {
              if (!currentSession.isCurrentUserKeeper()) {
                return TransitionCard(
                  type: TotemCardTransitionType.start,
                  onActionPressed: currentSession.startSession,
                );
              } else {
                return const GroundingMarquee();
              }
            }
          }();

          if (isLandscape) {
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
                              ?marquee,
                              Center(child: actionBar),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
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
                  ?marquee,
                  Center(child: actionBar),
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
    this.gap = 10,
    this.isLandscape = false,
  });

  final SessionDetailSchema event;
  final String? speakingNow;
  final double gap;
  final bool isLandscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantKeys = ref.watch(sessionParticipantKeysProvider);
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticipants: participants,
      state: sessionState,
      speakingNow: speakingNow,
    );
    final itemCount = sortedParticipants.length;
    if (itemCount == 0) return const SizedBox.shrink();

    late final int crossAxisCount;
    if (isLandscape) {
      if (itemCount <= 2) {
        crossAxisCount = 2;
      } else if (itemCount <= 4) {
        crossAxisCount = 2;
      } else if (itemCount <= 6) {
        crossAxisCount = 3;
      } else {
        crossAxisCount = 4;
      }
    } else {
      if (itemCount <= 6) {
        crossAxisCount = 3;
      } else if (itemCount <= 12) {
        crossAxisCount = 4;
      } else {
        crossAxisCount = 5;
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
