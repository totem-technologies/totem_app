import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/shared/widgets/viewport_resolver.dart';

/// Header for large screen session views, showing session and speaker information.
class SessionStatusHeader extends ConsumerWidget {
  const SessionStatusHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final roomStatus = ref.watch(roomStatusProvider);
    final amNext = ref.watch(amNextSpeakerProvider);
    final currentSession = ref.watch(currentSessionProvider)!;
    final currentSessionState = ref.watch(currentSessionStateProvider)!;
    final activeSpeaker = ref.watch(featuredParticipantProvider);
    final nextUp = ref.watch(speakingNextParticipantProvider);

    return ViewportResolver(
      builder: (context, viewportKind) {
        assert(
          viewportKind == ViewportKind.mediumPlus,
          'SessionStatusHeader should only be used in large viewports',
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 20.0,
                vertical: 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${currentSessionState.participants.participants.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' Participants'),
                        ],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        if (currentSession.event != null) ...[
                          Text(
                            currentSession.event!.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currentSession.event!.space.title,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (roomStatus == RoomStatus.active)
                    Expanded(
                      child: Column(
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: activeSpeaker?.name ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const TextSpan(text: ' Now speaking'),
                              ],
                              style: theme.textTheme.bodyMedium,
                            ),
                            textAlign: TextAlign.start,
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                if (amNext)
                                  const TextSpan(
                                    text: 'You are Next',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else if (nextUp != null) ...[
                                  const TextSpan(text: 'Next up '),
                                  TextSpan(
                                    text: nextUp.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ],
                              style: theme.textTheme.bodyMedium,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ),
            Divider(
              color: switch (roomStatus) {
                RoomStatus.waitingRoom => AppTheme.slate,
                _ => AppTheme.cream,
              },
            ),
          ],
        );
      },
    );
  }
}
