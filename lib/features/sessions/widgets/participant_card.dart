import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    hide AudioVisualizerWidgetOptions, SoundWaveformWidget;
// livekit_components exports provider
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

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
        clipBehavior: Clip.hardEdge,
        child: ClipRRect(
          // radius - border width
          borderRadius: BorderRadius.circular(20 - 2),
          clipBehavior: Clip.hardEdge,
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
                              t.track!.isActive &&
                              t.participant.isCameraEnabled(),
                        );
                    if (videoTrack.isNotEmpty) {
                      return VideoTrackRenderer(
                        videoTrack.first.track! as VideoTrack,
                        fit: VideoViewFit.cover,
                      );
                    } else {
                      final user = ref.watch(
                        userProfileProvider(participant.identity),
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
                    padding: const EdgeInsetsDirectional.all(2),
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
                start: 4,
                end: 4,
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

class LocalParticipantVideoCard extends ConsumerWidget {
  const LocalParticipantVideoCard({
    this.isCameraOn = true,
    this.videoTrack,
    super.key,
  });

  final bool isCameraOn;
  final VideoTrack? videoTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    return Container(
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: 40,
        vertical: 10,
      ),
      alignment: Alignment.center,
      // DecoratedBox is overlapping the border
      // ignore: use_decorated_box
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: AspectRatio(
            aspectRatio: 16 / 21,
            child: Builder(
              builder: (context) {
                if (!isCameraOn) {
                  return Container(
                    decoration: BoxDecoration(
                      image: auth.user?.profileImage != null
                          ? DecorationImage(
                              image: NetworkImage(
                                getFullUrl(auth.user!.profileImage!),
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    alignment: AlignmentDirectional.bottomCenter,
                    padding: const EdgeInsetsDirectional.all(20),
                    child: AutoSizeText(
                      auth.user?.name ?? 'You',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: kElevationToShadow[6],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  );
                } else if (videoTrack == null) {
                  return const LoadingIndicator();
                }
                return VideoTrackRenderer(
                  videoTrack!,
                  fit: VideoViewFit.cover,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
