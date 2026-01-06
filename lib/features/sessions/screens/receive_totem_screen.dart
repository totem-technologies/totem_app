import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

class ReceiveTotemScreen extends StatelessWidget {
  const ReceiveTotemScreen({
    required this.actionBar,
    required this.onAcceptTotem,
    required this.sessionState,
    super.key,
  });

  final Widget actionBar;
  final Future<void> Function() onAcceptTotem;
  final SessionRoomState sessionState;

  @override
  Widget build(BuildContext context) {
    final room = RoomContext.of(context)!;

    return RoomBackground(
      status: sessionState.sessionState.status,
      padding: const EdgeInsetsDirectional.all(20),
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            const titleWidget = SizedBox(height: 0);

            final videoCard = Padding(
              padding: const EdgeInsetsDirectional.all(20),
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
            );

            final passReceiveCard = TransitionCard(
              type: TotemCardTransitionType.receive,
              onActionPressed: () async {
                try {
                  await onAcceptTotem();
                  return true;
                } catch (error) {
                  return false;
                }
              },
            );

            if (isLandscape) {
              return Row(
                spacing: 16,
                children: [
                  Expanded(child: videoCard),
                  Expanded(
                    flex: 2,
                    child: Column(
                      spacing: 20,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        titleWidget,
                        passReceiveCard,
                        actionBar,
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                spacing: 40,
                children: [
                  titleWidget,
                  Expanded(
                    child: videoCard,
                  ),
                  passReceiveCard,
                  actionBar,
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
