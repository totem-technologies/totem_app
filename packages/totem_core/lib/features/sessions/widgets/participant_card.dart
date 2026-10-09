import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';

import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media_providers.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/loading_video_placeholder.dart';
import 'package:totem_core/features/sessions/widgets/participant_control_button.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';
import 'package:totem_core/features/sessions/widgets/participant_tile_surface.dart';
import 'package:totem_core/features/sessions/widgets/session_text.dart';
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
      authControllerProvider.select((auth) => auth.user?.slug.value),
    );
    final participantKeys = ref.watch(sessionParticipantKeysProvider);
    final hasSession = ref.watch(
      currentSessionStateProvider.select((session) => session != null),
    );
    if (!hasSession) return const SizedBox.shrink();

    final activeSpeaker = ref.watch(featuredParticipantProvider);
    final roomStatus = ref.watch(roomStatusProvider);
    final hasKeeper = ref.watch(hasKeeperProvider);
    final keeperIdentity = ref.watch(
      currentSessionStateProvider.select(
        (session) => session?.roomState.keeper,
      ),
    );
    final isCurrentUserKeeper = ref.watch(isCurrentUserKeeperProvider);

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
        clipBehavior: Clip.antiAlias,
        borderRadius: speakerVideoBorderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (roomStatus == RoomStatus.waitingRoom && !hasKeeper)
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
              const Positioned.fill(child: ColoredBox(color: Colors.black54))
            else ...[
              Positioned.fill(
                child: ParticipantVideo(
                  key: participantKeys.getKey(activeSpeaker.sid),
                  participant: activeSpeaker,
                ),
              ),
              // Only the overlays depend on the card size, so the video stays
              // outside the builder and skips the constraint-driven rebuilds.
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Chrome scales with the card, so the hero tile's badges
                    // stay proportional to the video instead of jumping at a
                    // breakpoint.
                    final overlay = ParticipantOverlayMetrics.forCard(
                      constraints.biggest,
                    );
                    return Stack(
                      children: [
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
                                if (keeperIdentity == activeSpeaker.identity)
                                  Container(
                                    padding:
                                        const EdgeInsetsDirectional.symmetric(
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
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
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
                                    if (isCurrentUserKeeper &&
                                        roomStatus == RoomStatus.active)
                                      const SessionElapsedTimer(),
                                    SpeakingIndicatorOrEmoji(
                                      participant: activeSpeaker,
                                      metrics: overlay,
                                    ),
                                    if (isCurrentUserKeeper &&
                                        currentUserSlug !=
                                            activeSpeaker.identity)
                                      ParticipantControlButton(
                                        menuVerticalOffset:
                                            -overlay.badgeSize - 8,
                                        participant: activeSpeaker,
                                        metrics: overlay,
                                      ),
                                    Flexible(
                                      child: SmartNameText(
                                        name: activeSpeaker.name,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
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
                    );
                  },
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
  const ParticipantCard({required this.participant, super.key});

  final ParticipantInfo participant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug.value),
    );
    final presentation = ref.watch(
      currentSessionStateProvider.select(
        (session) =>
            sessionParticipantPresentation(session, participant.identity),
      ),
    );
    final isCurrentUserKeeper = ref.watch(isCurrentUserKeeperProvider);
    final participantKeys = ref.watch(sessionParticipantKeysProvider);

    return ParticipantTileSurface(
      children: [
        Positioned.fill(
          child: ParticipantVideo(
            key: participantKeys.getKey(participant.sid),
            participant: participant,
          ),
        ),
        // Only the overlays depend on the tile size, so the video stays
        // outside the builder and skips the constraint-driven rebuilds.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Chrome scales with the tile, so a dense grid keeps compact
              // badges while a sparse one grows them.
              final overlay = ParticipantOverlayMetrics.forCard(
                constraints.biggest,
              );
              final overlayPadding = overlay.cornerInset;

              return Stack(
                children: [
                  PositionedDirectional(
                    top: overlayPadding,
                    start: overlayPadding,
                    child: SpeakingIndicatorOrEmoji(
                      participant: participant,
                      metrics: overlay,
                    ),
                  ),
                  if (presentation.hasSession &&
                      isCurrentUserKeeper &&
                      currentUserSlug != participant.identity)
                    PositionedDirectional(
                      end: overlayPadding,
                      top: overlayPadding,
                      child: ParticipantControlButton(
                        participant: participant,
                        menuVerticalOffset: overlayPadding,
                        metrics: overlay,
                      ),
                    )
                  else if (presentation.isKeeper)
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
                        padding: EdgeInsetsDirectional.all(
                          overlay.badgePadding,
                        ),
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
                        shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class ParticipantVideo extends ConsumerWidget {
  const ParticipantVideo({required this.participant, super.key});

  final ParticipantInfo participant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(roomMediaProvider);
    final isStaff = ref.watch(
      authControllerProvider.select((auth) => auth.user?.isStaff == true),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: _ParticipantVideoAvatar(identity: participant.identity),
          ),
        ),
        if (media != null)
          Positioned.fill(
            child: media.video(participant, showStats: kDebugMode || isStaff),
          ),
      ],
    );
  }
}

class _ParticipantVideoAvatar extends StatelessWidget {
  const _ParticipantVideoAvatar({required this.identity});

  final String identity;

  @override
  Widget build(BuildContext context) {
    return UserAvatar.slug(
      identity,
      radius: 0,
      borderRadius: BorderRadius.zero,
      borderWidth: 0,
      loading: const LoadingVideoPlaceholder(borderRadius: 0),
      error: const ColoredBox(
        color: AppTheme.mauve,
        child: Center(
          child: TotemIcon(TotemIcons.person, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}
