import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';

class MyTurn extends StatelessWidget {
  const MyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Card(
              margin: const EdgeInsetsDirectional.symmetric(horizontal: 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: 20,
                  start: 30,
                  end: 30,
                  bottom: 30,
                ),
                child: Column(
                  spacing: 15,
                  children: [
                    Text(
                      'When done, press Pass to pass '
                      'the Totem to the next person.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 160,
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO(bdlukaa): Pass the totem functionality
                        },
                        style: ButtonStyle(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                        child: const Text('Pass'),
                      ),
                    ),
                  ],
                ),
              ),
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
