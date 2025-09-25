import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    hide AudioVisualizerWidgetOptions, SoundWaveformWidget;
// livekit_components exports provider
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class SessionParticipantsLayoutBuilder implements ParticipantLayoutBuilder {
  const SessionParticipantsLayoutBuilder({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        //                          card width + spacing + factor spacing
        final crossAxisCount = (width / (76 + 10 + 10 / 2)).floor().clamp(
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
              math.max(children.length, crossAxisCount * 2),
              (index) {
                if (index < children.length) {
                  return children[index].widget;
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class ParticipantCard extends ConsumerWidget {
  const ParticipantCard({required this.participant, super.key});

  final Participant participant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final room = RoomContext.of(context);
    final participantContext = Provider.of<ParticipantContext>(context);

    final audioTracks = participantContext.tracks
        .where(
          (t) => t.kind == TrackType.AUDIO || t.track is AudioTrack,
        )
        .toList();

    return AspectRatio(
      aspectRatio: 16 / 21,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: participantContext.isSpeaking
                ? const Color(0xFFFFD000)
                : Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 3),
              blurRadius: 1,
              spreadRadius: -2,
              color: participantContext.isSpeaking
                  ? const Color(0x80FFD000)
                  : Colors.black,
            ),
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 2,
              color: participantContext.isSpeaking
                  ? const Color(0x80FFD000)
                  : Colors.black,
            ),
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 5,
              color: participantContext.isSpeaking
                  ? const Color(0x80FFD000)
                  : Colors.black,
            ),
          ],
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Builder(
                  builder: (context) {
                    final videoTrack = participant.trackPublications.values
                        .where(
                          (t) =>
                              t.track != null &&
                              t.kind == TrackType.VIDEO &&
                              t.track!.isActive,
                        );
                    if (videoTrack.isNotEmpty) {
                      return VideoTrackRenderer(
                        videoTrack.first.track! as VideoTrack,
                        fit: VideoViewFit.cover,
                      );
                    } else {
                      final user = ref.watch(
                        userProfileProvider(
                          participant.identity,
                        ),
                      );
                      return user.when(
                        data: (user) {
                          return IgnorePointer(
                            child: UserAvatar.fromUserSchema(
                              user,
                              borderRadius: BorderRadius.zero,
                              borderWidth: 0,
                            ),
                          );
                        },
                        error: (error, stackTrace) {
                          return const ColoredBox(
                            color: AppTheme.mauve,
                            child: Center(
                              child: TotemIcon(
                                TotemIcons.person,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                        loading: LoadingPlaceholder.new,
                      );
                    }
                  },
                ),
              ),
              if (audioTracks.isNotEmpty)
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x262F3799),
                    ),
                    padding: const EdgeInsets.all(2),
                    alignment: Alignment.center,
                    child: SoundWaveformWidget(
                      audioTrack: audioTracks.first.track! as AudioTrack,
                      participant: participant,
                      options: const AudioVisualizerWidgetOptions(
                        color: Colors.white,
                        barCount: 3,
                        barMinOpacity: 0.8,
                        spacing: 3,
                        minHeight: 4,
                        maxHeight: 12,
                      ),
                    ),
                  ),
                ),
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
