import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';
import 'package:totem_app/features/sessions/services/utils.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.sessionState,
    required this.event,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final SessionState sessionState;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final roomCtx = RoomContext.of(context)!;
    final speakingNow = roomCtx.participants.firstWhere(
      (participant) {
        if (sessionState.speakingNow != null) {
          return participant.identity == sessionState.speakingNow;
        } else {
          // If no one is speaking right now, show the keeper's video
          return participant.identity == event.space.author.slug!;
        }
      },
      orElse: () => roomCtx.localParticipant!,
    );

    return RoomBackground(
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
                    child: ParticipantVideo(participant: speakingNow),
                  ),
                  PositionedDirectional(
                    end: 30,
                    bottom: 30,
                    child: Text(
                      speakingNow.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          final participantGrid = ParticipantLoop(
            layoutBuilder: NoMyTurnLayoutBuilder(isLandscape: isLandscape),
            sorting: (originalTracks) {
              return tracksSorting(
                context: context,
                originalTracks: originalTracks,
                sessionState: sessionState,
                event: event,
              );
            },
            participantTrackBuilder: (context, identifier) {
              return ParticipantCard(
                participant: identifier.participant,
                event: event,
              );
            },
          );

          if (isLandscape) {
            final isLTR = Directionality.of(context) == TextDirection.ltr;
            return SafeArea(
              top: false,
              left: !isLTR,
              right: isLTR,
              child: Row(
                spacing: 16,
                children: [
                  Expanded(
                    flex: 2,
                    child: speakerVideo,
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      spacing: 16,
                      children: [
                        Expanded(child: participantGrid),
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 16,
                          ),
                          child: actionBar,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return SafeArea(
              top: false,
              child: Column(
                spacing: 20,
                children: [
                  Expanded(
                    flex: 3,
                    child: speakerVideo,
                  ),
                  Flexible(flex: 2, child: participantGrid),
                  actionBar,
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class NoMyTurnLayoutBuilder implements ParticipantLayoutBuilder {
  const NoMyTurnLayoutBuilder({
    this.maxPerLineCount,
    this.gap = 10,
    this.isLandscape = false,
  });

  /// The amount of participants to show per line.
  ///
  /// If there are less participants than this number, it will show only the
  /// available participants.
  final int? maxPerLineCount;

  final double gap;

  final bool isLandscape;

  @override
  Widget build(
    BuildContext context,
    List<TrackWidget> children,
    List<String> pinnedTracks,
  ) {
    final itemCount = children.length;
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
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isLandscape ? 16 : 28,
        vertical: isLandscape ? 16 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: gap,
        children: List.generate(
          rowCount,
          (rowIndex) {
            final startIndex = rowIndex * crossAxisCount;

            return Expanded(
              child: Row(
                spacing: gap,
                children: List.generate(
                  crossAxisCount,
                  (colIndex) {
                    final itemIndex = startIndex + colIndex;
                    if (itemIndex < itemCount) {
                      return Expanded(
                        child: children[itemIndex].widget,
                      );
                    } else {
                      return const Expanded(
                        child: SizedBox.shrink(),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
