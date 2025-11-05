import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_components/livekit_components.dart';
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
        }
        return participant.isSpeaking;
      },
      orElse: () => roomCtx.localParticipant!,
    );

    return RoomBackground(
      child: SafeArea(
        top: false,
        child: Column(
          spacing: 20,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppTheme.blue,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ParticipantVideo(participant: speakingNow),
                      ),
                      PositionedDirectional(
                        end: 20,
                        bottom: 20,
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
              ),
            ),
            Flexible(
              child: ParticipantLoop(
                layoutBuilder: const NoMyTurnLayoutBuilder(),
                participantTrackBuilder: (context, identifier) {
                  return ParticipantCard(
                    key: getParticipantKey(
                      identifier.participant.identity,
                    ),
                    participant: identifier.participant,
                    event: event,
                  );
                },
              ),
            ),
            // TODO(bdlukaa): Transcriptions
            actionBar,
          ],
        ),
      ),
    );
  }
}

class NoMyTurnLayoutBuilder implements ParticipantLayoutBuilder {
  const NoMyTurnLayoutBuilder({
    this.maxPerLineCount,
    this.gap = 10,
  });

  /// The amount of participants to show per line.
  ///
  /// If there are less participants than this number, it will show only the
  /// available participants.
  final int? maxPerLineCount;

  final double gap;

  @override
  Widget build(
    BuildContext context,
    List<TrackWidget> children,
    List<String> pinnedTracks,
  ) {
    final itemCount = children.length;
    int crossAxisCount;
    if (itemCount <= 3) {
      crossAxisCount = 3;
    } else if (itemCount <= 5) {
      crossAxisCount = itemCount;
    } else if (itemCount <= 10) {
      crossAxisCount = (itemCount / 2).ceil();
    } else {
      crossAxisCount = 5;
    }
    return Center(
      child: GridView.count(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 28,
          vertical: 10,
        ),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: 16 / 21,
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
