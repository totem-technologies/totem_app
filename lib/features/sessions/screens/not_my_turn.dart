import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';

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
                            final track =
                                roomCtx.localVideoTrack ??
                                user?.videoTrackPublications
                                    .firstWhereOrNull(
                                      (pub) => pub.track != null,
                                    )
                                    ?.track;

                            if (track != null && track.isActive) {
                              return VideoTrackRenderer(
                                track,
                                fit: VideoViewFit.cover,
                              );
                            } else {
                              return Container(
                                decoration: BoxDecoration(
                                  image: auth.user?.profileImage != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            auth.user!.profileImage!,
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
                layoutBuilder: const SessionParticipantsLayoutBuilder(),
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
