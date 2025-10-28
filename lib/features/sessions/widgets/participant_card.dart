import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    hide AudioVisualizerWidgetOptions, SoundWaveformWidget;
// livekit_components exports provider
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class ParticipantCard extends ConsumerWidget {
  const ParticipantCard({
    required this.participant,
    required this.event,
    super.key,
  });

  final Participant participant;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantContext = Provider.of<ParticipantContext>(context);

    final audioTracks = participantContext.tracks
        .where(
          (t) => t.kind == TrackType.AUDIO || t.track is AudioTrack,
        )
        .toList();

    final isKeeper = participant.identity == event.space.author.slug!;

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
                child: ParticipantVideo(participant: participant),
              ),
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
                  child: Builder(
                    builder: (context) {
                      if (participant.isMuted ||
                          !participant.hasAudio ||
                          audioTracks.isEmpty) {
                        return const TotemIcon(
                          TotemIcons.microphoneOff,
                          size: 20,
                          color: Colors.white,
                        );
                      } else {
                        return SoundWaveformWidget(
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
                        );
                      }
                    },
                  ),
                ),
              ),
              if (isKeeper)
                PositionedDirectional(
                  end: 6,
                  top: 6,
                  child: PopupMenuButton(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withValues(alpha: 0.8),
                    position: PopupMenuPosition.under,
                    itemBuilder: (context) {
                      return [
                        if (participant.hasAudio)
                          PopupMenuItem<void>(
                            onTap: () => _onMuteParticipant(context, ref),
                            child: Row(
                              spacing: 8,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const TotemIcon(
                                  TotemIcons.microphoneOff,
                                  size: 24,
                                  color: Colors.white,
                                ),
                                Text(
                                  participant.isMuted ? 'Muted' : 'Mute',
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem<void>(
                          onTap: () => _onRemoveParticipant(context, ref),
                          child: const Row(
                            spacing: 8,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TotemIcon(
                                TotemIcons.removePerson,
                                size: 24,
                                color: Colors.white,
                              ),
                              Text('Remove'),
                            ],
                          ),
                        ),
                      ];
                    },
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

  Future<void> _onMuteParticipant(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final user = ref.watch(userProfileProvider(participant.identity));
        return ConfirmationDialog(
          iconWidget: user
              .whenData(
                (user) => UserAvatar.fromUserSchema(
                  user,
                  radius: 40,
                ),
              )
              .value,
          confirmButtonText: 'Mute',
          title: 'Mute ${participant.name}',
          content: 'They can unmute themselves anytime.',
          onConfirm: () async {
            await ref.read(
              muteParticipantProvider(
                event.slug,
                participant.identity,
              ).future,
            );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          type: ConfirmationDialogType.standard,
        );
      },
    );
  }

  Future<void> _onRemoveParticipant(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final user = ref.watch(userProfileProvider(participant.identity));
        return ConfirmationDialog(
          iconWidget: user
              .whenData(
                (user) => UserAvatar.fromUserSchema(
                  user,
                  radius: 40,
                ),
              )
              .value,
          confirmButtonText: 'Remove',
          content:
              'Are you sure you want to remove '
              '${participant.name}?',
          onConfirm: () async {
            await ref.read(
              removeParticipantProvider(
                event.slug,
                participant.identity,
              ).future,
            );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
        );
      },
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: ClipRRect(
          // radius - border width
          borderRadius: BorderRadius.circular(30 - 2),
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

class ParticipantVideo extends ConsumerWidget {
  const ParticipantVideo({required this.participant, super.key});

  final Participant<TrackPublication<Track>> participant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoTrack = participant.videoTrackPublications.where(
      (t) =>
          t.track != null &&
          t.kind == TrackType.VIDEO &&
          t.track!.isActive &&
          t.participant.isCameraEnabled(),
    );
    if (videoTrack.isNotEmpty) {
      return VideoTrackRenderer(
        videoTrack.last.track! as VideoTrack,
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
        loading: LoadingVideoPlaceholder.new,
      );
    }
  }
}
