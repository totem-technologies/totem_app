import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

class ReceiveTotemScreen extends ConsumerWidget {
  const ReceiveTotemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatus = ref.watch(roomStatusProvider);
    final session = ref.watch(currentSessionProvider);
    final roundPrompt = ref.watch(roundMessageProvider);

    Future<bool> onAccept() async {
      try {
        ref.read(sessionCuesServiceProvider).pulseSwipeCompletion();
        await session?.keeper.acceptTotem();
        return true;
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Accept Totem failed',
        );
        if (context.mounted) {
          NotificationController().showError(
            context,
            icon: TotemIcons.errorOutlined,
            title: 'Something went wrong',
            message: 'We were unable to accept the totem. Please try again.',
          );
        }

        return false;
      }
    }

    return RoomBackground(
      status: sessionStatus,
      child: SafeArea(
        child: ViewportResolver(
          builder: (context, viewportKind) {
            final theme = Theme.of(context);
            final titleWidget = Column(
              spacing: 16,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 50,
                  ),
                  child: Text(
                    'The totem is being passed to you.',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Text(
                    "We'll hide your self-view during your turn so you can stay in the moment. Everyone else will still see you. You can disable your camera at any time.",
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );

            final videoCard = Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
              child: AspectRatio(
                aspectRatio: 16 / 21,
                child: ParticipantCard(
                  participant: session!.room!.localParticipant!,
                  session: session.event,
                  participantIdentity: session.room!.localParticipant!.identity,
                ),
              ),
            );

            final roundPromptText = roundPrompt != null
                ? Text(
                    '"$roundPrompt"',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  )
                : null;

            final receiveSlider = Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 20,
                children: [
                  ?roundPromptText,
                  SizedBox(
                    height: 50,
                    child: ActionSliderButton(
                      text: 'Receive',
                      onActionCompleted: onAccept,
                      keepLoadingOnSuccess: true,
                    ),
                  ),
                ],
              ),
            );

            switch (viewportKind) {
              case ViewportKind.smallPortrait:
                return Padding(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: Column(
                    spacing: 40,
                    children: [
                      titleWidget,
                      Expanded(child: videoCard),
                      receiveSlider,
                      const SessionActionBar(),
                    ],
                  ),
                );
              case ViewportKind.smallLandscape:
                return Padding(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: Row(
                    spacing: 16,
                    children: [
                      Expanded(child: videoCard),
                      Expanded(
                        flex: 2,
                        child: Column(
                          spacing: 20,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            titleWidget,
                            receiveSlider,
                            const SessionActionBar(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              case ViewportKind.mediumPlus:
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: 40.0,
                    bottom: 28,
                  ),
                  child: Column(
                    spacing: 40,
                    children: [
                      const SizedBox(),
                      Expanded(child: videoCard),
                      roundPromptText ?? const SizedBox(height: 10),
                      ReceiveTransitionCard(
                        onActionPressed: onAccept,
                        keepActionLoadingOnSuccess: true,
                      ),
                      const SessionActionBar(),
                    ],
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
