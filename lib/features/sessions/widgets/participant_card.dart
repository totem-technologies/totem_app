import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class ParticipantCard extends ConsumerWidget {
  const ParticipantCard({
    required this.participant,
    required this.event,
    required this.participantIdentity,
    super.key,
  });

  final Participant participant;
  final SessionDetailSchema event;
  final String participantIdentity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    final currentUserIsKeeper = currentUserSlug == event.space.author.slug!;

    const overlayPadding = 6.0;
    final isKeeper = event.space.author.slug == participant.identity;
    final shadowColor = isKeeper ? const Color(0x80FFD000) : Colors.black45;

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 16 / 21,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isKeeper ? const Color(0xFFFFD000) : Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 3),
                blurRadius: 1,
                spreadRadius: -2,
                color: shadowColor,
              ),
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 2,
                color: shadowColor,
              ),
              BoxShadow(
                offset: const Offset(0, 1),
                blurRadius: 5,
                color: shadowColor,
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ParticipantVideo(participant: participant),
                ),
                PositionedDirectional(
                  top: overlayPadding,
                  start: overlayPadding,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final emojis = ref.watch(
                        participantEmojisProvider(participantIdentity),
                      );
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        child: emojis.isNotEmpty
                            ? Container(
                                key: ValueKey(emojis.first),
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  emojis.first,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    textBaseline: TextBaseline.ideographic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : child,
                      );
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      padding: const EdgeInsetsDirectional.all(2),
                      alignment: Alignment.center,
                      child: SpeakingIndicator(
                        participant: participant,
                      ),
                    ),
                  ),
                ),
                if (currentUserIsKeeper &&
                    currentUserSlug != participant.identity)
                  PositionedDirectional(
                    end: overlayPadding,
                    top: overlayPadding,
                    child: ParticipantControlButton(
                      participant: participant,
                      overlayPadding: overlayPadding,
                      event: event,
                    ),
                  ),
                PositionedDirectional(
                  bottom: 8,
                  start: 6,
                  end: 6,
                  child: AutoSizeText(
                    participant.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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
      ),
    );
  }
}

class ParticipantControlButton extends ConsumerWidget {
  const ParticipantControlButton({
    required this.participant,
    required this.overlayPadding,
    required this.event,
    this.backgroundColor = Colors.black54,
    super.key,
  });

  final Participant participant;
  final double overlayPadding;
  final SessionDetailSchema event;

  final Color backgroundColor;

  static const _menuTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTapUp: (details) => _showParticipantMenu(context, ref, details),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        padding: const EdgeInsetsDirectional.all(2),
        alignment: Alignment.center,
        child: const TotemIcon(
          TotemIcons.moreVertical,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _showParticipantMenu(
    BuildContext context,
    WidgetRef ref,
    TapUpDetails details,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = _calculateMenuPosition(
      tapPosition: details.globalPosition,
      cardSize: box.size,
      screenSize: MediaQuery.sizeOf(context),
    );

    await showMenu(
      context: context,
      constraints: const BoxConstraints(),
      position: position,
      color: Colors.black.withValues(alpha: 0.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 0,
      menuPadding: EdgeInsetsDirectional.zero,
      clipBehavior: Clip.hardEdge,
      items: _buildMenuItems(context, ref),
    );
  }

  RelativeRect _calculateMenuPosition({
    required Offset tapPosition,
    required Size cardSize,
    required Size screenSize,
  }) {
    return RelativeRect.fromLTRB(
      tapPosition.dx - cardSize.width + overlayPadding * 2,
      tapPosition.dy + overlayPadding * 2.5,
      screenSize.width - tapPosition.dx,
      screenSize.height - tapPosition.dy,
    );
  }

  List<PopupMenuEntry<void>> _buildMenuItems(
    BuildContext context,
    WidgetRef ref,
  ) {
    return [
      if (participant.hasAudio)
        PopupMenuItem<void>(
          enabled: !participant.isMuted,
          onTap: () => _onMuteParticipant(context, ref),
          textStyle: _menuTextStyle,
          child: Row(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            children: [
              const TotemIcon(
                TotemIcons.microphoneOff,
                size: 20,
                color: Colors.white,
              ),
              Text(
                participant.isMuted ? 'Muted' : 'Mute',
                style: _menuTextStyle,
              ),
            ],
          ),
        ),
      PopupMenuItem<void>(
        onTap: () => _onRemoveParticipant(context, ref),
        textStyle: _menuTextStyle,
        child: const Row(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: [
            TotemIcon(
              TotemIcons.removePerson,
              size: 20,
              color: Colors.white,
            ),
            Text('Remove', style: _menuTextStyle),
          ],
        ),
      ),
    ];
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

class SpeakingIndicator extends StatelessWidget {
  const SpeakingIndicator({
    required this.participant,
    this.foregroundColor = Colors.white,
    this.barCount = 3,
    super.key,
  });

  final Participant participant;
  final Color foregroundColor;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final audioTracks = participant
        .getTrackPublications()
        .where((t) => t.kind == TrackType.AUDIO && t.track is AudioTrack)
        .toList();
    if (participant.isMuted || !participant.hasAudio || audioTracks.isEmpty) {
      return TotemIcon(
        TotemIcons.microphoneOff,
        size: 20,
        color: foregroundColor,
      );
    } else {
      return RepaintBoundary(
        child: SoundWaveformWidget(
          audioTrack: audioTracks.firstOrNull?.track as AudioTrack?,
          participant: participant,
          options: AudioVisualizerWidgetOptions(
            color: foregroundColor,
            barCount: barCount,
            barMinOpacity: 0.8,
            spacing: 3,
            minHeight: 4,
            maxHeight: 12,
          ),
        ),
      );
    }
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
    final user = ref.watch(
      authControllerProvider.select((auth) => auth.user),
    );
    return Container(
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
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
                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: UserAvatar(
                          radius: 0,
                          borderRadius: BorderRadius.zero,
                          borderWidth: 0,
                        ),
                      ),
                      PositionedDirectional(
                        bottom: 14,
                        start: 14,
                        end: 14,
                        child: AutoSizeText(
                          user?.name ?? 'You',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: kElevationToShadow[6],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  );
                } else if (videoTrack == null) {
                  return const LoadingIndicator();
                }
                return RepaintBoundary(
                  child: VideoTrackRenderer(
                    videoTrack!,
                    fit: VideoViewFit.cover,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ParticipantVideo extends ConsumerStatefulWidget {
  const ParticipantVideo({required this.participant, super.key});

  final Participant<TrackPublication<Track>> participant;

  @override
  ConsumerState<ParticipantVideo> createState() => _ParticipantVideoState();
}

class _ParticipantVideoState extends ConsumerState<ParticipantVideo> {
  late final EventsListener<ParticipantEvent> _listener;
  Timer? _statsTimer;
  static const _statsPollInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _listener = widget.participant.createListener();
    _listener.listen((event) => _scheduleStatsCheck());
    _checkVideoStats();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _listener
      ..cancelAll()
      ..dispose();
    super.dispose();
  }

  void _scheduleStatsCheck() {
    if (_statsTimer?.isActive ?? false) return;
    _statsTimer = Timer(_statsPollInterval, _checkVideoStats);
  }

  bool _active = true;
  void _checkVideoStats() async {
    final videoTrack =
        widget.participant.videoTrackPublications.firstOrNull?.track
            as RemoteVideoTrack?;
    if (videoTrack == null) return;
    final stats = await videoTrack.getReceiverStats();

    if (!mounted) return;
    final fps = stats?.framesPerSecond;
    if (fps == null || fps == 0) {
      if (_active) {
        setState(() => _active = false);
      }
    } else {
      if (!_active) setState(() => _active = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoTrack = widget.participant.videoTrackPublications.where(
      (t) =>
          t.track != null &&
          t.kind == TrackType.VIDEO &&
          t.track!.isActive &&
          t.participant.isCameraEnabled() &&
          !t.track!.muted,
    );
    if (_active && videoTrack.isNotEmpty) {
      return IgnorePointer(
        child: RepaintBoundary(
          child: VideoTrackRenderer(
            key: ValueKey(videoTrack.last.track!.sid),
            videoTrack.last.track! as VideoTrack,
            fit: VideoViewFit.cover,
          ),
        ),
      );
    } else {
      final localUser = ref.watch(
        authControllerProvider.select((auth) => auth.user),
      );
      if (widget.participant.identity == localUser?.slug) {
        return const UserAvatar(
          radius: 0,
          borderRadius: BorderRadius.zero,
          borderWidth: 0,
        );
      }

      final user = ref.watch(userProfileProvider(widget.participant.identity));
      return IgnorePointer(
        child: user.when(
          data: (user) {
            return UserAvatar.fromUserSchema(
              user,
              borderRadius: BorderRadius.zero,
              borderWidth: 0,
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
          loading: () => const LoadingVideoPlaceholder(borderRadius: 0),
        ),
      );
    }
  }
}
