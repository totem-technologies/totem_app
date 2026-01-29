import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.sessionState,
    required this.session,
    required this.event,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final SessionRoomState sessionState;
  final Session session;
  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    final amKeeper = currentUserSlug == event.space.author.slug!;
    final activeSpeaker = session.speakingNowParticipant();

    return RoomBackground(
      status: sessionState.sessionState.status,
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
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppTheme.blue),
              child: Stack(
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
                                event: event,
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
            ),
          );

          final nextUp = session.speakingNextParticipant();
          final nextUpText =
              sessionState.sessionState.status == SessionStatus.waiting
              ? Text(
                  () {
                    if (!session.hasKeeperEverJoined) {
                      return 'Waiting for the Keeper to join...';
                    }
                    return 'The session is about to start...';
                  }(),
                  style: theme.textTheme.bodyLarge,
                )
              : sessionState.sessionState.status == SessionStatus.started &&
                    nextUp != null
              ? RichText(
                  text: TextSpan(
                    children: [
                      if (sessionState.amNext(session.context))
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
                )
              : const SizedBox.shrink();

          final participantGrid = NotMyTurnGrid(
            sessionState: sessionState,
            buildParticipant: (context, participant) {
              return ParticipantCard(
                key: getParticipantKey(participant.identity),
                participant: participant,
                event: event,
                participantIdentity: participant.identity,
              );
            },
            speakingNow: activeSpeaker.identity,
          );

          final Widget? startCard =
              sessionState.sessionState.status == SessionStatus.waiting &&
                  session.isKeeper()
              ? TransitionCard(
                  type: TotemCardTransitionType.start,
                  onActionPressed: session.startSession,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  Expanded(flex: 3, child: speakerVideo),
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

class NotMyTurnGrid extends StatelessWidget {
  const NotMyTurnGrid({
    required this.sessionState,
    required this.buildParticipant,
    required this.speakingNow,
    this.maxPerLineCount,
    this.gap = 10,
    this.isLandscape = false,
    super.key,
  });

  /// The amount of participants to show per line.
  ///
  /// If there are less participants than this number, it will show only the
  /// available participants.
  final int? maxPerLineCount;

  /// The gap between participants.
  final double gap;

  /// Whether the layout is in landscape mode.
  final bool isLandscape;

  final String speakingNow;

  /// The session state.
  final SessionRoomState sessionState;

  final Widget Function(BuildContext context, Participant participant)
  buildParticipant;

  @override
  Widget build(BuildContext context) {
    final sortedParticipants = participantsSorting(
      originalParticiapnts: sessionState.participants,
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
      if (itemCount <= 3) {
        crossAxisCount = 3;
      } else if (itemCount <= 5) {
        crossAxisCount = itemCount;
      } else if (itemCount <= 10) {
        crossAxisCount = (itemCount / 2).ceil();
      } else {
        crossAxisCount = 5;
      }
    }

    final rowCount = (itemCount / crossAxisCount).ceil();
    return Column(
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
              children: List.generate(
                crossAxisCount,
                (colIndex) {
                  final itemIndex = startIndex + colIndex;
                  if (itemIndex < itemCount) {
                    return Expanded(
                      child: Builder(
                        builder: (context) {
                          return buildParticipant(
                            context,
                            sortedParticipants[itemIndex],
                          );
                        },
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
