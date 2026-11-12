import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/features/sessions/widgets/smart_name_text.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

/// The pre-join camera preview, rendered from the preview track before the
/// session's media backend exists.
class LocalParticipantCard extends ConsumerWidget {
  const LocalParticipantCard({
    this.isCameraOn = true,
    this.videoTrack,
    super.key,
  });

  final bool isCameraOn;
  final VideoTrack? videoTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));
    return LocalParticipantCardView(
      isCameraOn: isCameraOn,
      videoTrack: videoTrack,
      avatar: const UserAvatar.currentUser(
        radius: 0,
        borderRadius: BorderRadius.zero,
        borderWidth: 0,
      ),
      name: user?.name.value ?? 'You',
    );
  }
}

/// Provider-free presentation for a pre-join participant preview.
class LocalParticipantCardView extends StatelessWidget {
  const LocalParticipantCardView({
    required this.avatar,
    required this.name,
    this.isCameraOn = true,
    this.videoTrack,
    super.key,
  });

  final Widget avatar;
  final String name;
  final bool isCameraOn;
  final VideoTrack? videoTrack;

  bool get _hasRenderer => videoTrack != null && videoTrack!.isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showVideo = isCameraOn && _hasRenderer && !videoTrack!.muted;

    return ClipRRect(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      borderRadius: BorderRadius.circular(30),
      child: AspectRatio(
        aspectRatio: 16 / 21,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo) Positioned.fill(child: IgnorePointer(child: avatar)),
            if (_hasRenderer)
              IgnorePointer(
                key: const ValueKey('prejoin-video-renderer'),
                child: VideoTrackRenderer(
                  videoTrack!,
                  key: ValueKey(videoTrack!.sid),
                  fit: VideoViewFit.cover,
                  renderMode: VideoRenderMode.platformView,
                ),
              ),
            if (!showVideo)
              Positioned.fill(child: IgnorePointer(child: avatar)),
            PositionedDirectional(
              bottom: 14,
              start: 14,
              end: 14,
              child: SmartNameText(
                name: name,
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
