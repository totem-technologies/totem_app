import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/services/livekit_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.sessionState,
    required this.session,
    required this.event,
    required this.emojis,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final SessionState sessionState;
  final LiveKitService session;
  final EventDetailSchema event;
  final List<MapEntry<String, String>> emojis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
                    child: ParticipantVideo(
                      key: getParticipantKey(session.speakingNow.identity),
                      participant: session.speakingNow,
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
                            child: SpeakingIndicator(
                              participant: session.speakingNow,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              session.speakingNow.name,
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

          final participantGrid = ParticipantLoop(
            layoutBuilder: NoMyTurnLayoutBuilder(isLandscape: isLandscape),
            sorting: (originalTracks) {
              return tracksSorting(
                speakingNow: session.speakingNow.identity,
                originalTracks: originalTracks,
                sessionState: sessionState,
                event: event,
              );
            },
            participantTrackBuilder: (context, identifier) {
              return ParticipantCard(
                key: getParticipantKey(identifier.participant.identity),
                participant: identifier.participant,
                event: event,
                emojis: emojis
                    .where(
                      (entry) => entry.key == identifier.participant.identity,
                    )
                    .map((entry) => entry.value)
                    .toList(),
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
                  Expanded(flex: 2, child: speakerVideo),
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
                  Expanded(flex: 2, child: participantGrid),
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
