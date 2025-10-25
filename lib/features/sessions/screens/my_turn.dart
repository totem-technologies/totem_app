import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';

class MyTurn extends StatelessWidget {
  const MyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.onPassTotem,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final Future<void> Function() onPassTotem;

  @override
  Widget build(BuildContext context) {
    return RoomBackground(
      child: SafeArea(
        child: Column(
          spacing: 20,
          children: [
            Expanded(
              child: ParticipantLoop(
                layoutBuilder: const MyTurnLayoutBuilder(),
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
            PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (context) {
                    return ConfirmationDialog(
                      content:
                          'Are you sure you want to pass the totem to the next '
                          'participant?',
                      confirmButtonText: 'Pass Totem',
                      type: ConfirmationDialogType.standard,
                      onConfirm: () async {
                        final navigator = Navigator.of(context);
                        await onPassTotem();
                        navigator.pop();
                      },
                    );
                  },
                );
              },
            ),
            actionBar,
          ],
        ),
      ),
    );
  }
}

class MyTurnLayoutBuilder implements ParticipantLayoutBuilder {
  const MyTurnLayoutBuilder({this.maxPerLineCount, this.gap = 16});

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = math
            .sqrt(children.length)
            .ceil()
            .clamp(
              1,
              maxPerLineCount ?? 10,
            );
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
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              children.length,
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
      },
    );
  }
}
