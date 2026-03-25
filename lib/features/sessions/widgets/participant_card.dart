import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/widgets/smart_name_text.dart';
import 'package:totem_app/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class FeaturedParticipantCard extends ConsumerWidget {
  const FeaturedParticipantCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    final participantKeys = ref.watch(sessionParticipantKeysProvider);
    final session = ref.watch(currentSessionStateProvider);

    if (session == null) {
      return const SizedBox.shrink();
    }

    final activeSpeaker = session.featuredParticipant();
    final amKeeper = session.isKeeper(currentUserSlug);

    final theme = Theme.of(context);
    final speakerVideoBorderRadius = switch (MediaQuery.orientationOf(
      context,
    )) {
      Orientation.landscape => const BorderRadiusDirectional.horizontal(
        end: Radius.circular(30),
      ),
      Orientation.portrait => const BorderRadiusDirectional.vertical(
        bottom: Radius.circular(30),
      ),
    };
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: speakerVideoBorderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (session.roomState.status == RoomStatus.waitingRoom &&
                !session.hasKeeper)
              Positioned.fill(
                child: Container(
                  color: AppTheme.slate,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 60,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 20,
                    children: [
                      const TotemIcon(
                        TotemIcons.clockCircle,
                        size: 70,
                        color: Colors.white,
                      ),
                      Text(
                        'Waiting room',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Please wait for your Keeper to arrive and begin the session.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (activeSpeaker == null)
              const Positioned.fill(
                child: ColoredBox(color: Colors.black54),
              )
            else ...[
              Positioned.fill(
                child: ParticipantVideo(
                  key: participantKeys.getKey(activeSpeaker.identity),
                  participant: activeSpeaker,
                  preferredVideoQuality: VideoQuality.HIGH,
                ),
              ),
              PositionedDirectional(
                start: 20,
                end: 20,
                bottom: 20,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        spacing: 12,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                              boxShadow: kElevationToShadow[6],
                            ),
                            padding: const EdgeInsetsDirectional.all(4),
                            child: SpeakingIndicatorOrEmoji(
                              participant: activeSpeaker,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          if (amKeeper &&
                              currentUserSlug != activeSpeaker.identity)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                                boxShadow: kElevationToShadow[6],
                              ),
                              padding: const EdgeInsetsDirectional.all(3),
                              child: ParticipantControlButton(
                                overlayPadding: -28,
                                participant: activeSpeaker,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          Flexible(
                            child: SmartNameText(
                              name: activeSpeaker.name,
                              style: theme.textTheme.titleLarge!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: kElevationToShadow[6],
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      if (session.isKeeper(activeSpeaker.identity))
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(42),
                            color: Colors.white.withValues(alpha: 0.3),
                            boxShadow: kElevationToShadow[6],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 5,
                            children: [
                              const TotemIconLogo(
                                color: Colors.white,
                                size: 16,
                              ),
                              Text(
                                'Keeper',
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ParticipantCard extends ConsumerWidget {
  const ParticipantCard({
    required this.participant,
    required this.session,
    required this.participantIdentity,
    super.key,
  });

  final Participant participant;
  final SessionDetailSchema? session;
  final String participantIdentity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    final session = ref.watch(currentSessionStateProvider);
    final currentUserIsKeeper = session?.isKeeper(currentUserSlug) ?? false;

    const overlayPadding = 10.0;
    final isKeeper = session?.isKeeper(participant.identity) ?? false;

    const borderRadius = 20.0;

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 16 / 21,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isKeeper ? AppTheme.yellow : Colors.white,
              width: 2,
            ),
            boxShadow: isKeeper
                ? const [
                    BoxShadow(
                      offset: Offset(0, 3),
                      blurRadius: 1,
                      spreadRadius: -2,
                      color: AppTheme.yellow,
                    ),
                    BoxShadow(
                      offset: Offset(0, 2),
                      blurRadius: 2,
                      color: AppTheme.yellow,
                    ),
                    BoxShadow(
                      offset: Offset(0, 1),
                      blurRadius: 5,
                      color: AppTheme.yellow,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.hardEdge,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 2),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ParticipantVideo(
                    participant: participant,
                    preferredVideoQuality: VideoQuality.MEDIUM,
                  ),
                ),
                PositionedDirectional(
                  top: overlayPadding,
                  start: overlayPadding,
                  child: SpeakingIndicatorOrEmoji(participant: participant),
                ),
                if (session != null &&
                    currentUserIsKeeper &&
                    currentUserSlug != participant.identity)
                  PositionedDirectional(
                    end: overlayPadding,
                    top: overlayPadding,
                    child: ParticipantControlButton(
                      participant: participant,
                      overlayPadding: overlayPadding,
                    ),
                  )
                else if (isKeeper)
                  PositionedDirectional(
                    top: overlayPadding,
                    end: overlayPadding,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        boxShadow: kElevationToShadow[6],
                      ),
                      padding: const EdgeInsetsDirectional.all(4),
                      child: const TotemIconLogo(
                        color: AppTheme.white,
                        size: 16,
                      ),
                    ),
                  ),
                PositionedDirectional(
                  bottom: 8,
                  start: 8,
                  end: 8,
                  child: SmartNameText(
                    name: participant.name,
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
    this.backgroundColor = Colors.black54,
    super.key,
  });

  final Participant participant;
  final double overlayPadding;

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
        width: 24,
        height: 24,
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
      items: _buildMenuItems(context),
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
  ) {
    return [
      if (participant.hasAudio)
        PopupMenuItem<void>(
          enabled: !participant.isMuted,
          onTap: () => _onMuteParticipant(context),
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
        onTap: () => _onRemoveParticipant(context),
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
      PopupMenuItem<void>(
        onTap: () => _onBanParticipant(context),
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
            Text('Ban', style: _menuTextStyle),
          ],
        ),
      ),
    ];
  }

  Future<void> _onMuteParticipant(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(userProfileProvider(participant.identity));
            final currentSession = ref.watch(currentSessionProvider);
            return ConfirmationDialog(
              iconWidget: user
                  .whenData(
                    (user) => UserAvatar.fromUserSchema(user, radius: 40),
                  )
                  .value,
              confirmButtonText: 'Mute',
              title: 'Mute ${participant.name}',
              content: 'They can unmute themselves anytime.',
              onConfirm: () async {
                try {
                  await currentSession?.moderation.muteParticipant(
                    participant.identity,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  await ErrorHandler.handleApiError(context, error);
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              type: ConfirmationDialogType.standard,
            );
          },
        );
      },
    );
  }

  Future<void> _onRemoveParticipant(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(userProfileProvider(participant.identity));
            final currentSession = ref.watch(currentSessionProvider);
            return ConfirmationDialog(
              iconWidget: user
                  .whenData(
                    (user) => UserAvatar.fromUserSchema(user, radius: 40),
                  )
                  .value,
              confirmButtonText: 'Remove',
              content:
                  'Are you sure you want to remove '
                  '${participant.name}?',
              onConfirm: () async {
                try {
                  await currentSession?.moderation.removeParticipant(
                    participant.identity,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  await ErrorHandler.handleApiError(context, error);
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _onBanParticipant(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(userProfileProvider(participant.identity));
            final currentSession = ref.watch(currentSessionProvider);
            return ConfirmationDialog(
              iconWidget: user
                  .whenData(
                    (user) => UserAvatar.fromUserSchema(user, radius: 40),
                  )
                  .value,
              confirmButtonText: 'Ban',
              content:
                  'Are you sure you want to ban '
                  '${participant.name}? They will not be able to rejoin the session.',
              onConfirm: () async {
                try {
                  await currentSession?.moderation.banParticipant(
                    participant.identity,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  await ErrorHandler.handleApiError(context, error);
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

class LocalParticipantVideoCard extends ConsumerWidget {
  const LocalParticipantVideoCard({
    this.isCameraOn = true,
    this.audioTrack,
    this.videoTrack,
    super.key,
  });

  final bool isCameraOn;
  final AudioTrack? audioTrack;
  final VideoTrack? videoTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(
      authControllerProvider.select((auth) => auth.user),
    );

    const overlayPadding = 12.0;

    final isVideoTrackVisible =
        videoTrack != null && videoTrack!.isActive && !videoTrack!.muted;
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideoTrackVisible)
                  IgnorePointer(
                    child: VideoTrackRenderer(
                      videoTrack!,
                      fit: VideoViewFit.cover,
                      renderMode: VideoRenderMode.platformView,
                    ),
                  )
                else
                  const LoadingVideoPlaceholder(),
                AnimatedOpacity(
                  opacity: (!isCameraOn || !isVideoTrackVisible) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 10),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: UserAvatar.currentUser(
                            radius: 0,
                            borderRadius: BorderRadius.zero,
                            borderWidth: 0,
                          ),
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
                  ),
                ),
                PositionedDirectional(
                  top: overlayPadding,
                  start: overlayPadding,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                      boxShadow: kElevationToShadow[6],
                    ),
                    padding: const EdgeInsetsDirectional.all(4),
                    alignment: Alignment.center,
                    child: SpeakingIndicatorAudioTrack(audioTrack: audioTrack),
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

class ParticipantVideo extends ConsumerStatefulWidget {
  const ParticipantVideo({
    required this.participant,
    this.preferredVideoQuality = VideoQuality.MEDIUM,
    super.key,
  });

  final Participant<TrackPublication<Track>> participant;
  final VideoQuality preferredVideoQuality;

  @override
  ConsumerState<ParticipantVideo> createState() => _ParticipantVideoState();
}

class _ParticipantVideoState extends ConsumerState<ParticipantVideo> {
  TrackPublication<Track>? get videoTrack {
    if (widget.participant is RemoteParticipant) {
      return widget.participant.getTrackPublicationBySource(TrackSource.camera);
    } else if (widget.participant is LocalParticipant) {
      return (widget.participant as LocalParticipant)
              .getTrackPublicationBySource(TrackSource.camera) ??
          widget.participant.videoTrackPublications
              .where(
                (t) => t.track != null && t.track!.isActive && !t.track!.muted,
              )
              .firstOrNull;
    } else {
      return widget.participant.videoTrackPublications
          .where((t) => t.track != null && t.track!.isActive && !t.track!.muted)
          .firstOrNull;
    }
  }

  EventsListener<ParticipantEvent>? _listener;
  EventsListener<TrackEvent>? _trackListener;
  VideoQuality? _lastAppliedQuality;
  String? _lastAppliedTrackSid;
  String? _listenedTrackSid;

  void _setupListeners() {
    _listener?.dispose();
    _listener = widget.participant.createListener()
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted)
      ..on<ParticipantEvent>(_onParticipantUpdated);

    _bindTrackListener();
  }

  void _bindTrackListener() {
    final publication = videoTrack;
    final trackSid = publication?.sid;
    final track = publication?.track;

    if (_listenedTrackSid == trackSid && _trackListener != null) {
      return;
    }

    _trackListener?.dispose();
    _trackListener = null;
    _listenedTrackSid = trackSid;

    if (track != null) {
      _trackListener = track.createListener()..listen(_onTrackEvent);
    }
  }

  Future<void> _applyPreferredRemoteQuality() async {
    final publication = videoTrack;
    if (publication == null) return;
    if (publication is! RemoteTrackPublication<RemoteTrack>) return;

    final desired = widget.preferredVideoQuality;
    final sameTrack = _lastAppliedTrackSid == publication.sid;
    final sameQuality = _lastAppliedQuality == desired;
    if (sameTrack && sameQuality) return;

    try {
      final previousQuality = _lastAppliedQuality;
      await publication.setVideoQuality(desired);
      _lastAppliedTrackSid = publication.sid;
      _lastAppliedQuality = desired;
      logger.i(
        'Participant video quality changed '
        '(identity=${widget.participant.identity}, sid=${publication.sid}): '
        '${previousQuality?.name ?? 'unset'} -> ${publication.videoQuality.name}',
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to set remote video quality',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
    scheduleMicrotask(_applyPreferredRemoteQuality);
  }

  void _onTrackMuted(TrackMutedEvent event) {
    if (event.publication.source != TrackSource.camera) return;
    if (!mounted) return;
    _bindTrackListener();
    setState(() {});
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    if (event.publication.source != TrackSource.camera) return;
    if (!mounted) return;
    _bindTrackListener();
    setState(() {});
  }

  // Whether the track is inactive due to poor network conditions.
  bool _isTrackInactive = false;
  void _onTrackEvent(TrackEvent event) {
    if (event is VideoReceiverStatsEvent) {
      final bitrate = event.currentBitrate;
      if (bitrate < 10) {
        _isTrackInactive = true;
      } else if (_isTrackInactive) {
        _isTrackInactive = false;
      }
    }
    if (mounted) setState(() {});
  }

  void _onParticipantUpdated(ParticipantEvent _) {
    _bindTrackListener();
    scheduleMicrotask(_applyPreferredRemoteQuality);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ParticipantVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid) {
      _setupListeners();
    }
    if (oldWidget.preferredVideoQuality != widget.preferredVideoQuality ||
        oldWidget.participant.identity != widget.participant.identity ||
        oldWidget.participant.sid != widget.participant.sid) {
      scheduleMicrotask(_applyPreferredRemoteQuality);
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _trackListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider(widget.participant.identity));
    final track = videoTrack;

    if (track != null &&
        track.subscribed &&
        !track.muted &&
        !_isTrackInactive) {
      return IgnorePointer(
        child: VideoTrackRenderer(
          key: ValueKey(track.track!.sid),
          track.track! as VideoTrack,
          fit: VideoViewFit.cover,
          // Use platform view for better CPU performance on iOS.
          // The [VideoTrackRenderer] widget only supports platform views for iOS.
          // On Android, it will still use the default texture rendering.
          // https://github.com/livekit/client-sdk-flutter/issues/364
          renderMode: VideoRenderMode.platformView,
        ),
      );
    } else {
      final localUserSlug = ref.watch(
        authControllerProvider.select((auth) => auth.user?.slug),
      );
      if (widget.participant.identity == localUserSlug) {
        return IgnorePointer(
          child: UserAvatar.currentUser(
            radius: 0,
            borderRadius: BorderRadius.zero,
            borderWidth: 0,
          ),
        );
      }

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
