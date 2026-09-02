import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/loading_video_placeholder.dart';
import 'package:totem_core/features/sessions/widgets/participant_control_button.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';
import 'package:totem_core/features/sessions/widgets/smart_name_text.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/totem_icon.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

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
    // Featured tiles keep a slightly larger compact badge (24dp) than grid tiles.
    final overlay = ParticipantOverlayMetrics.featuredOf(context);
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
                  key: participantKeys.getKey(activeSpeaker.sid),
                  participant: activeSpeaker,
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
                    spacing: 2,
                    children: [
                      if (session.isKeeper(activeSpeaker.identity))
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(42),
                            color: Colors.black54,
                            boxShadow: kElevationToShadow[1],
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        spacing: 12,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (amKeeper &&
                              session.roomState.status == RoomStatus.active)
                            const _ElapsedTimer(),
                          SpeakingIndicatorOrEmoji(
                            participant: activeSpeaker,
                            metrics: overlay,
                          ),
                          if (amKeeper &&
                              currentUserSlug != activeSpeaker.identity)
                            ParticipantControlButton(
                              menuVerticalOffset: -overlay.badgeSize - 8,
                              participant: activeSpeaker,
                              metrics: overlay,
                            ),
                          Flexible(
                            child: SmartNameText(
                              name: activeSpeaker.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: kElevationToShadow[6],
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
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

class _ElapsedTimer extends ConsumerStatefulWidget {
  const _ElapsedTimer();

  @override
  ConsumerState<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends ConsumerState<_ElapsedTimer> {
  Timer? _tick;
  DateTime? _start;

  @override
  void initState() {
    super.initState();
    _start = ref.read(featuredTurnStartTimeProvider);
    _syncTimer();
    ref.listenManual(featuredTurnStartTimeProvider, (_, next) {
      setState(() => _start = next);
      _syncTimer();
    });
  }

  void _syncTimer() {
    _tick?.cancel();
    if (_start != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_start == null) return const SizedBox.shrink();

    final elapsed = DateTime.now().difference(_start!);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(42),
        color: Colors.black54,
      ),
      child: Text(
        _format(elapsed),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
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
    final amKeeper = session?.isKeeper(currentUserSlug) ?? false;
    final participantKeys = ref.watch(sessionParticipantKeysProvider);

    final overlay = ParticipantOverlayMetrics.of(context);
    final overlayPadding = overlay.cornerInset;
    final isKeeper = session?.isKeeper(participant.identity) ?? false;
    final isSpeaking = participant.identity == session?.speakingNow;

    const borderRadius = 20.0;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: ParticipantVideo(
                key: participantKeys.getKey(participant.sid),
                participant: participant,
              ),
            ),
            PositionedDirectional(
              top: overlayPadding,
              start: overlayPadding,
              child: Row(
                spacing: 8,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpeakingIndicatorOrEmoji(participant: participant),
                  if (amKeeper &&
                      isSpeaking &&
                      session?.roomState.status == RoomStatus.active)
                    const _ElapsedTimer(),
                ],
              ),
            ),
            if (session != null &&
                amKeeper &&
                currentUserSlug != participant.identity)
              PositionedDirectional(
                end: overlayPadding,
                top: overlayPadding,
                child: ParticipantControlButton(
                  participant: participant,
                  menuVerticalOffset: overlayPadding,
                ),
              )
            else if (isKeeper)
              PositionedDirectional(
                top: overlayPadding,
                end: overlayPadding,
                child: Container(
                  width: overlay.badgeSize,
                  height: overlay.badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                    boxShadow: kElevationToShadow[6],
                  ),
                  padding: EdgeInsetsDirectional.all(overlay.badgePadding),
                  child: TotemIconLogo(
                    color: AppTheme.white,
                    size: overlay.iconSize,
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
    );
  }
}

class LocalParticipantCard extends ConsumerWidget {
  const LocalParticipantCard({
    this.isCameraOn = true,
    this.audioTrack,
    this.videoTrack,
    super.key,
  });

  final bool isCameraOn;
  final AudioTrack? audioTrack;
  final VideoTrack? videoTrack;

  bool get _isVideoTrackVisible =>
      videoTrack != null && videoTrack!.isActive && !videoTrack!.muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(
      authControllerProvider.select((auth) => auth.user),
    );

    final showVideo = isCameraOn && _isVideoTrackVisible;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: AspectRatio(
        aspectRatio: 16 / 21,
        child: Stack(
          fit: StackFit.expand,
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
            AnimatedSwitcher(
              duration: kThemeAnimationDuration,
              child: showVideo
                  ? IgnorePointer(
                      child: VideoTrackRenderer(
                        videoTrack!,
                        key: ValueKey(videoTrack!.sid),
                        fit: VideoViewFit.cover,
                        renderMode: VideoRenderMode.platformView,
                      ),
                    )
                  : const SizedBox(),
            ),
            PositionedDirectional(
              bottom: 14,
              start: 14,
              end: 14,
              child: SmartNameText(
                name: user?.name ?? 'You',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: kElevationToShadow[6],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
  final GlobalKey videoKey = GlobalKey();

  EventsListener<ParticipantEvent>? _listener;
  void _setupListeners() {
    _listener?.dispose();
    _listener = widget.participant.createListener()
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted)
      ..on<ParticipantEvent>(_onParticipantUpdated);
  }

  void _onTrackMuted(TrackMutedEvent event) {
    if (event.publication.source != TrackSource.camera) return;
    if (!mounted) return;
    setState(() {});
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    if (event.publication.source != TrackSource.camera) return;
    if (!mounted) return;
    setState(() {});
  }

  void _onParticipantUpdated(ParticipantEvent _) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(
      authControllerProvider.select((auth) => auth.user),
    );
    final user = ref.watch(userProfileProvider(widget.participant.identity));
    final trackPublication = videoTrack;

    /// The user avatar is always rendered behind the video.
    ///
    ///  1. If the user swipes the app away or close the browser tab and stops emitting data,
    ///     the video turns transparent and the user avatar remains visible.
    ///  2. If the user disabled their camera (muted track), the user avatar remains visible.
    ///  3. In all other cases, the video is displayed normally.
    final content = Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: widget.participant.identity == currentUser?.slug
                ? UserAvatar.currentUser(
                    radius: 0,
                    borderRadius: BorderRadius.zero,
                    borderWidth: 0,
                  )
                : user.when(
                    data: (user) => UserAvatar.fromUserSchema(
                      user,
                      borderRadius: BorderRadius.zero,
                      borderWidth: 0,
                    ),
                    error: (error, stackTrace) => const ColoredBox(
                      color: AppTheme.mauve,
                      child: Center(
                        child: TotemIcon(
                          TotemIcons.person,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    loading: () =>
                        const LoadingVideoPlaceholder(borderRadius: 0),
                  ),
          ),
        ),
        if (trackPublication != null &&
            trackPublication.track != null &&
            trackPublication.subscribed &&
            !trackPublication.muted)
          IgnorePointer(
            child: VideoTrackRenderer(
              key: videoKey,
              trackPublication.track! as VideoTrack,
              fit: VideoViewFit.cover,
              renderMode: VideoRenderMode.platformView,
            ),
          ),
      ],
    );

    if (kDebugMode || currentUser?.isStaff == true) {
      return _ParticipantVideoStatistics(
        participant: widget.participant,
        trackPublication: trackPublication,
        child: content,
      );
    }

    return content;
  }
}

class _ParticipantVideoStatistics extends StatefulWidget {
  const _ParticipantVideoStatistics({
    required this.participant,
    required this.trackPublication,
    required this.child,
  });

  final Participant<TrackPublication<Track>> participant;
  final TrackPublication<Track>? trackPublication;
  final Widget child;

  @override
  State<_ParticipantVideoStatistics> createState() =>
      _ParticipantVideoStatisticsState();
}

class _ParticipantVideoStatisticsState
    extends State<_ParticipantVideoStatistics> {
  // --- Debug Stats State ---
  int _currentBitrate = 0;
  num frameHeight = 0;
  num frameWidth = 0;
  num fps = 0;
  String? qualityLimitationReason;
  String? decoderImplementation;
  String? mimeType;

  void resetStats() {
    _currentBitrate = frameHeight = frameWidth = 0;
    qualityLimitationReason = decoderImplementation = mimeType = null;
    fps = 0;
  }

  EventsListener<TrackEvent>? _trackListener;
  String? _listenedTrackSid;

  void _setupListeners() {
    final track = widget.trackPublication?.track;
    final trackSid = track?.sid;

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

  @override
  void initState() {
    super.initState();
    // When user is a local participant, the track is not inactive by default.
    if (widget.participant is LocalParticipant) {
      _isTrackInactive = false;
    } else {
      _isTrackInactive = true;
    }
    _setupListeners();
  }

  // Whether the track is inactive due to poor network conditions.
  late bool _isTrackInactive;

  void _onTrackEvent(TrackEvent event) {
    if (!mounted) return;

    if (event is VideoReceiverStatsEvent) {
      resetStats();

      final bitrate = event.currentBitrate;
      setState(() {
        frameHeight = event.stats.frameHeight ?? 0;
        frameWidth = event.stats.frameWidth ?? 0;
        fps = event.stats.framesPerSecond ?? 0;
        decoderImplementation = event.stats.decoderImplementation;
        mimeType = event.stats.mimeType;

        _currentBitrate = bitrate.round();
        _isTrackInactive = bitrate <= 0;
      });
    } else if (event is VideoSenderStatsEvent) {
      resetStats();

      setState(() {
        final stats = event.stats.values.lastOrNull;
        frameHeight = stats?.frameHeight ?? 0;
        frameWidth = stats?.frameWidth ?? 0;
        fps = stats?.framesPerSecond ?? 0;
        qualityLimitationReason = stats?.qualityLimitationReason;
        mimeType = stats?.mimeType;
        _currentBitrate = event.currentBitrate.round();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ParticipantVideoStatistics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid ||
        oldWidget.trackPublication?.track?.sid !=
            widget.trackPublication?.track?.sid) {
      _setupListeners();
    }
  }

  @override
  void dispose() {
    _trackListener?.dispose();
    super.dispose();
  }

  bool _shouldShowStatistics = kDebugMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(
        () => _shouldShowStatistics = !_shouldShowStatistics,
      ),
      child: _shouldShowStatistics
          ? Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Bitrate: $_currentBitrate\n'
                        'Res: ${frameWidth}x$frameHeight\n'
                        'FPS: $fps\n'
                        'Mime: ${mimeType ?? 'None'}\n'
                        'Is off: $_isTrackInactive',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : widget.child,
    );
  }
}
