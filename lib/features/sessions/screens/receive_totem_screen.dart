import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

class ReceiveTotemScreen extends StatelessWidget {
  const ReceiveTotemScreen({
    required this.actionBar,
    required this.onAcceptTotem,
    super.key,
  });

  final Widget actionBar;
  final VoidCallback onAcceptTotem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = RoomContext.of(context)!;

    return RoomBackground(
      padding: const EdgeInsetsDirectional.all(20),
      child: SafeArea(
        child: Column(
          spacing: 20,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
              child: Text(
                'The totem is being passed to you',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: LocalParticipantVideoCard(
                isCameraOn: room.localParticipant!.isCameraEnabled(),
                videoTrack:
                    room.localParticipant?.trackPublications.values
                            .where(
                              (t) =>
                                  t.track != null &&
                                  t.kind == TrackType.VIDEO &&
                                  t.track!.isActive,
                            )
                            .firstOrNull
                            ?.track
                        as VideoTrack?,
              ),
            ),
            PassReceiveCard(
              type: TotemCardTransitionType.receive,
              onActionPressed: () {
                // TODO(bdlukaa): Receive the totem functionality
              },
            ),
            actionBar,
          ],
        ),
      ),
    );
  }
}
