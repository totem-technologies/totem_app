import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/core/layout/layout.dart';
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
  final Future<void> Function() onAcceptTotem;

  @override
  Widget build(BuildContext context) {
    final room = RoomContext.of(context)!;
    final theme = Theme.of(context);
    final titleWidget = Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
      child: Text(
        'The Totem is being passed to you',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );

    final videoCard = LocalParticipantVideoCard(
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
    );

    final passReceiveCard = PassReceiveCard(
      type: TotemCardTransitionType.receive,
      onActionPressed: onAcceptTotem,
    );

    return RoomBackground(
      padding: const EdgeInsetsDirectional.all(20),
      child: SafeArea(
        child: AdaptiveLayout(
          mobilePortrait: Column(
            spacing: 20,
            children: [
              titleWidget,
              Expanded(
                child: videoCard,
              ),
              passReceiveCard,
              actionBar,
            ],
          ),
          mobileLandscape: Builder(
            builder: (context) {
              return Row(
                spacing: context.layoutInfo.gridSpacing,
                children: [
                  Expanded(child: videoCard),
                  Expanded(
                    flex: 2,
                    child: Column(
                      spacing: context.layoutInfo.gridSpacing,
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
            },
          ),
        ),
      ),
    );
  }
}
