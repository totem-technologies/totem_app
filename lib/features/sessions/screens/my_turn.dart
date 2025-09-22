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
    return RoomBackground(
      child: SafeArea(
        child: Column(
          spacing: 20,
          children: [
            Expanded(
              child: ParticipantLoop(
                // TODO(bdlukaa): Update this layout builder
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
                      style: Theme.of(context).textTheme.bodyLarge,
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
