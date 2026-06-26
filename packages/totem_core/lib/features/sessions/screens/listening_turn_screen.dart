import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/adaptive_call_layout.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/grounding_marquee.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

class ListeningTurnScreen extends ConsumerWidget {
  const ListeningTurnScreen({required this.event, super.key});

  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomStatus = ref.watch(roomStatusProvider);
    final amNext = ref.watch(amNextSpeakerProvider);
    final activeSpeaker = ref.watch(featuredParticipantProvider);
    final nextUp = ref.watch(speakingNextParticipantProvider);
    final hasKeeper = ref.watch(hasKeeperProvider);

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

          final participantGrid = _ListeningTurnGrid(
            event: event,
            speakingNow: activeSpeaker?.identity,
          );

          final Widget? marquee = roomStatus == RoomStatus.waitingRoom
              ? const GroundingMarquee()
              : null;

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
                    ?marquee,
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
                                ?marquee,
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
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: 40,
                  bottom: 28,
                  start: 60,
                  end: 60,
                ),
                child: Column(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Center(
                        child: _ListeningTurnGrid(
                          event: event,
                          speakingNow: activeSpeaker?.identity,
                          showSpeakingNowParticipant: true,
                          gap: 20,
                        ),
                      ),
                    ),
                    if (roomStatus == RoomStatus.waitingRoom) ...[
                      const SizedBox.shrink(),
                      ?marquee,
                      const SizedBox.shrink(),
                    ],
                    const Center(child: SessionActionBar()),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}

class _ListeningTurnGrid extends ConsumerWidget {
  const _ListeningTurnGrid({
    required this.event,
    required this.speakingNow,
    this.showSpeakingNowParticipant = false,
    this.gap = 10,
  });

  final SessionDetailSchema event;
  final String? speakingNow;
  final bool showSpeakingNowParticipant;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticipants: participants,
      state: sessionState,
      speakingNow: speakingNow,
      showSpeakingNow: showSpeakingNowParticipant,
    );

    // debug:
    // sortedParticipants = [for (var i = 0; i < 3; i++) ...sortedParticipants];
    return ViewportResolver(
      builder: (context, viewportKind) {
        switch (viewportKind) {
          case ViewportKind.smallLandscape:
          case ViewportKind.smallPortrait:
            final itemCount = sortedParticipants.length;
            if (itemCount == 0) return const SizedBox.shrink();

            int minRowCount = 1;
            late final int crossAxisCount;
            switch (viewportKind) {
              case ViewportKind.smallPortrait:
                minRowCount = 2;
                if (itemCount <= 6) {
                  crossAxisCount = 3;
                } else if (itemCount <= 12) {
                  crossAxisCount = 4;
                } else {
                  crossAxisCount = 5;
                }
              case ViewportKind.smallLandscape:
                if (itemCount <= 4) {
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
                } else if (itemCount <= 6) {
                  crossAxisCount = 3;
                } else if (itemCount <= 12) {
                  crossAxisCount = 4;
                } else {
                  crossAxisCount = math.sqrt(itemCount).ceil();
                }
            }
            final rowCount = (itemCount / crossAxisCount).ceil().clamp(
              minRowCount,
              100,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: List.generate(
                rowCount,
                (rowIndex) {
                  final startIndex = rowIndex * crossAxisCount;

                  return Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: gap,
                      children: List<Widget>.generate(
                        crossAxisCount,
                        (colIndex) {
                          final itemIndex = startIndex + colIndex;
                          if (itemIndex < itemCount) {
                            final participant = sortedParticipants[itemIndex];
                            return Expanded(
                              child: ParticipantCard(
                                key: ValueKey(participant.sid),
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
          case ViewportKind.mediumPlus:
            final speaker = showSpeakingNowParticipant
                ? participants.firstWhereOrNull(
                    (p) => p.identity == speakingNow,
                  )
                : null;

            return AdaptiveCallLayout(
              speaker: speaker == null
                  ? null
                  : ParticipantCard(
                      key: ValueKey(speaker.sid),
                      participant: speaker,
                      session: event,
                      participantIdentity: speaker.identity,
                    ),
              participants: [
                for (final participant in sortedParticipants.where(
                  (participant) => participant.identity != speaker?.identity,
                ))
                  ParticipantCard(
                    key: ValueKey(participant.sid),
                    participant: participant,
                    session: event,
                    participantIdentity: participant.identity,
                  ),
              ],
            );
        }
      },
    );
  }
}
