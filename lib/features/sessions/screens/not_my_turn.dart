// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.event,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionStatus = ref.watch(roomStatusProvider);
    final amNext = ref.watch(amNextSpeakerProvider);
    final currentSession = ref.watch(currentSessionProvider)!;

    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    final amKeeper = currentUserSlug == event.space.author.slug!;
    final activeSpeaker = currentSession.speakingNowParticipant();

    return RoomBackground(
      status: sessionStatus,
      child: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          final speakerVideo = ClipRRect(
            borderRadius: isLandscape
                ? const BorderRadiusDirectional.horizontal(
                    end: Radius.circular(30),
                  )
                : const BorderRadiusDirectional.vertical(
                    bottom: Radius.circular(30),
                  ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ParticipantVideo(
                    key: getParticipantKey(activeSpeaker.identity),
                    participant: activeSpeaker,
                  ),
                ),
                PositionedDirectional(
                  start: 20,
                  end: 20,
                  bottom: 20,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      spacing: 12,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                            border: Border.all(
                              color: Colors.white,
                              width: 0.5,
                            ),
                            boxShadow: kElevationToShadow[6],
                          ),
                          padding: const EdgeInsetsDirectional.all(4),
                          child: SpeakingIndicatorOrEmoji(
                            participant: activeSpeaker,
                          ),
                        ),
                        if (amKeeper &&
                            currentUserSlug != activeSpeaker.identity)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                              border: Border.all(
                                color: Colors.white,
                                width: 0.5,
                              ),
                              boxShadow: kElevationToShadow[6],
                            ),
                            padding: const EdgeInsetsDirectional.all(3),
                            child: ParticipantControlButton(
                              overlayPadding: -28,
                              session: event,
                              participant: activeSpeaker,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            activeSpeaker.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: kElevationToShadow[6],
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          final nextUp = currentSession.speakingNextParticipant();
          final nextUpText = () {
            if (sessionStatus == RoomStatus.waitingRoom) {
              return Text(
                () {
                  if (!currentSession.hasKeeper) {
                    return 'Waiting for the Keeper to join...';
                  }
                  return 'The session is about to start...';
                }(),
                style: theme.textTheme.bodyLarge,
              );
            } else if (sessionStatus == RoomStatus.active) {
              if (!currentSession.hasKeeper) {
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
            getParticipantKey: getParticipantKey,
            event: event,
            speakingNow: activeSpeaker.identity,
            isLandscape: isLandscape,
          );

          final Widget? startCard =
              sessionStatus == RoomStatus.waitingRoom &&
                  currentSession.isKeeper()
              ? TransitionCard(
                  type: TotemCardTransitionType.start,
                  onActionPressed: currentSession.startSession,
                )
              : null;

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
                  Expanded(flex: 2, child: speakerVideo),
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
                              ?startCard,
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
              // TODO(bdlukaa): Check if this should be true.
              // No need to avoid bottom safe area because the app is in fullscreen
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  SizedBox(
                    height: MediaQuery.heightOf(context) * 0.475,
                    child: speakerVideo,
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
                  ?startCard,
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
    required this.getParticipantKey,
    required this.event,
    required this.speakingNow,
    this.gap = 10,
    this.isLandscape = false,
  });

  final GlobalKey Function(String) getParticipantKey;
  final SessionDetailSchema event;
  final String speakingNow;
  final double gap;
  final bool isLandscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticiapnts: participants,
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
                        key: getParticipantKey(participant.identity),
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
