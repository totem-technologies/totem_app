import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    hide AudioVisualizerWidgetOptions, SoundWaveformWidget;
// livekit_components exports provider
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';

class SessionParticipantsLayoutBuilder implements ParticipantLayoutBuilder {
  const SessionParticipantsLayoutBuilder();

  @override
  Widget build(
    BuildContext context,
    List<TrackWidget> children,
    List<String> pinnedTracks,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = (width / 76).floor().clamp(1, 3);
        return Center(
          child: GridView.count(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 28,
              vertical: 10,
            ),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 16 / 21,
            shrinkWrap: true,
            children: List.generate(math.max(children.length, 8), (index) {
              if (index < children.length) {
                return children[index].widget;
              } else {
                return const SizedBox.shrink();
              }
            }),
          ),
        );
      },
    );
  }
}

class ParticipantCard extends StatelessWidget {
  const ParticipantCard({
    required this.participant,
    required this.child,
    super.key,
  });

  final Participant participant;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final participantContext = Provider.of<ParticipantContext>(context);

    // final audioTracks = participantContext.tracks
    //     .where(
    //       (t) => t.kind == TrackType.AUDIO || t is AudioTrack,
    //     )
    //     .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: participantContext.isSpeaking
              ? const Color(0xFFFFD000)
              : Colors.white,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: AspectRatio(
        aspectRatio: 16 / 21,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Stack(
            children: [
              child,
              // TODO(bdlukaa): Audio visualizer
              // if (audioTracks.isNotEmpty)
              //   PositionedDirectional(
              //     top: 6,
              //     start: 6,
              //     child: Container(
              //       width: 30,
              //       height: 30,
              //       decoration: const BoxDecoration(
              //         shape: BoxShape.circle,
              //         color: Color(0x262F3799),
              //       ),
              //       child: SoundWaveformWidget(
              //         audioTrack: audioTracks.first.track! as AudioTrack,
              //         participant: participant,
              //         options: AudioVisualizerWidgetOptions(
              //           color: Colors.white,
              //           barCount: 3,
              //           barMinOpacity: 0.8,
              //         ),
              //       ),
              //     ),
              //   ),
              PositionedDirectional(
                bottom: 6,
                start: 0,
                end: 0,
                child: Text(
                  participant.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
