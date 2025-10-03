import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/shared/network.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    final roomCtx = RoomContext.of(context)!;
    final room = roomCtx.room;
    final user = room.localParticipant;

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
                        child: Builder(
                          builder: (context) {
                            final Participant? speakingCurrently =
                                roomCtx.participants.firstWhereOrNull((p) {
                                  // TODO(bdlukaa): Check who the totem is at
                                  //                this point
                                  return p.isSpeaking;
                                }) ??
                                roomCtx.localParticipant;

                            VideoTrack? videoTrack;
                            if (speakingCurrently != null) {
                              videoTrack =
                                  speakingCurrently.videoTrackPublications
                                          .firstWhereOrNull(
                                            (pub) =>
                                                pub.track != null &&
                                                pub.track!.isActive,
                                          )
                                          ?.track
                                      as VideoTrack?;
                            }

                            if (videoTrack != null && videoTrack.isActive) {
                              return VideoTrackRenderer(
                                videoTrack,
                                fit: VideoViewFit.cover,
                              );
                            } else {
                              // TODO(bdlukaa): If the person speaking doesn't
                              //                have the camera on, show their
                              //                profile image instead.
                              // This depends on the user object for each person
                              return Container(
                                decoration: BoxDecoration(
                                  image: auth.user?.profileImage != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            getFullUrl(
                                              auth.user!.profileImage!,
                                            ),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      PositionedDirectional(
                        end: 20,
                        bottom: 20,
                        child: Text(
                          user?.identity ?? 'Me',
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
