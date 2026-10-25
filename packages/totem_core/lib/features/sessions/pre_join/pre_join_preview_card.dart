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

  bool get _hasRenderer => videoTrack != null && videoTrack!.isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));
    final showVideo = isCameraOn && _hasRenderer && !videoTrack!.muted;

    return ClipRRect(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      borderRadius: BorderRadius.circular(30),
      child: AspectRatio(
        aspectRatio: 16 / 21,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: UserAvatar.currentUser(
                  radius: 0,
                  borderRadius: BorderRadius.zero,
                  borderWidth: 0,
                ),
              ),
            ),
            if (_hasRenderer)
              IgnorePointer(
                child: VideoTrackRenderer(
                  videoTrack!,
                  key: ValueKey(videoTrack!.sid),
                  fit: VideoViewFit.cover,
                  renderMode: VideoRenderMode.platformView,
                ),
              ),
            if (!showVideo)
              const Positioned.fill(
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
              child: SmartNameText(
                name: user?.name.value ?? 'You',
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
