import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_components/livekit_components.dart';
// We need the defaultSorting function from livekit_components
// ignore: implementation_imports
import 'package:livekit_components/src/ui/layout/sorting.dart'
    show defaultSorting;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';
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
              final tracks = originalTracks.where((track) {
                // Only show tracks from participants other than the speaking
                // now
                return track.trackIdentifier.participant.identity !=
                    speakingNow.identity;
              });

              if (sessionState.speakingOrder != null &&
                  sessionState.speakingOrder!.isNotEmpty) {
                final sortedTracks = <TrackWidget>[];
                final tracksMap = {
                  for (final t in tracks)
                    t.trackIdentifier.participant.identity: t,
                };

                for (final identity in sessionState.speakingOrder!) {
                  if (tracksMap.containsKey(identity)) {
                    sortedTracks.add(tracksMap[identity]!);
                  }
                }
                for (final MapEntry(:key, :value) in tracksMap.entries) {
                  if (!sessionState.speakingOrder!.contains(key)) {
                    sortedTracks.add(value);
                  }
                }

                return sortedTracks;
              }

              return defaultSorting(tracks.toList());
            },
            participantTrackBuilder: (context, identifier) {
              return ParticipantCard(
                key: getParticipantKey(identifier.participant.identity),
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
                    child: speakerVideo,
                  ),
                  Expanded(
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
                    flex: 2,
                    child: speakerVideo,
                  ),
                  Flexible(child: participantGrid),
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
    int crossAxisCount;
    double childAspectRatio;

    if (isLandscape) {
      // Optimize for landscape: fewer columns, more rows
      if (itemCount <= 2) {
        crossAxisCount = 2;
      } else if (itemCount <= 4) {
        crossAxisCount = 2;
      } else if (itemCount <= 6) {
        crossAxisCount = 3;
      } else {
        crossAxisCount = 3;
      }
      childAspectRatio = 16 / 21;
    } else {
      // Portrait orientation logic
      if (itemCount <= 3) {
        crossAxisCount = 3;
      } else if (itemCount <= 5) {
        crossAxisCount = itemCount;
      } else if (itemCount <= 10) {
        crossAxisCount = (itemCount / 2).ceil();
      } else {
        crossAxisCount = 5;
      }
      childAspectRatio = 16 / 21;
    }

    return Center(
      child: GridView.count(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: isLandscape ? 16 : 28,
          vertical: isLandscape ? 16 : 10,
        ),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: childAspectRatio,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        children: List.generate(
          itemCount,
          (index) {
            if (index < children.length) {
              return children[index].widget;
            } else {
              return SizedBox.shrink(key: ValueKey<int>(index));
            }
          },
        ),
      ),
    );
  }
}
