import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media_providers.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';
import 'package:totem_core/shared/totem_icons.dart';

class SpeakingIndicator extends ConsumerWidget {
  const SpeakingIndicator({
    required this.participant,
    this.foregroundColor = Colors.white,
    this.barCount = 3,
    this.iconSize = 20,
    super.key,
  });

  final ParticipantInfo participant;
  final Color foregroundColor;
  final int barCount;

  /// Mic-off glyph size. Defaults to 20 so this widget stays overlay-agnostic.
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(roomMediaProvider);
    if (media == null) {
      return TotemIcon(
        TotemIcons.microphoneOff,
        size: iconSize,
        color: foregroundColor,
      );
    }
    return media.microphoneLevel(
      participant,
      color: foregroundColor,
      iconSize: iconSize,
      barCount: barCount,
    );
  }
}

class SpeakingIndicatorOrEmoji extends StatelessWidget {
  const SpeakingIndicatorOrEmoji({
    required this.participant,
    required this.metrics,
    this.backgroundColor = Colors.black54,
    super.key,
  });

  final ParticipantInfo participant;
  final Color backgroundColor;

  /// Chrome sizes, resolved by the card from its own size.
  final ParticipantOverlayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final emojis = ref.watch(
          participantEmojisProvider(participant.identity),
        );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: emojis.isNotEmpty
              ? MediaQuery.withNoTextScaling(
                  child: Container(
                    key: ValueKey(emojis.first),
                    width: metrics.badgeSize,
                    height: metrics.badgeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: kElevationToShadow[6],
                    ),
                    alignment: AlignmentDirectional.center,
                    child: Text(
                      emojis.first,
                      style: TextStyle(
                        fontSize: metrics.emojiFontSize,
                        textBaseline: TextBaseline.ideographic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : child,
        );
      },
      child: Container(
        width: metrics.badgeSize,
        height: metrics.badgeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: kElevationToShadow[6],
        ),
        padding: EdgeInsetsDirectional.all(metrics.badgePadding),
        alignment: AlignmentDirectional.center,
        child: SpeakingIndicator(
          participant: participant,
          iconSize: metrics.iconSize,
        ),
      ),
    );
  }
}
