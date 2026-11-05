import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';

import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/features/sessions/widgets/session_text.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

class ReceiveTotemScreen extends ConsumerStatefulWidget {
  const ReceiveTotemScreen({super.key});

  @override
  ConsumerState<ReceiveTotemScreen> createState() => _ReceiveTotemScreenState();
}

class _ReceiveTotemScreenState extends ConsumerState<ReceiveTotemScreen> {
  final _notificationController = NotificationController();

  @override
  void dispose() {
    _notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final localParticipant = ref.watch(localParticipantInfoProvider);
    final roundPrompt = ref.watch(currentSessionPromptProvider);
    final selfViewEnabled = ref.watch(
      selfViewSettingsProvider.select((settings) => settings.enabled),
    );

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
          _notificationController.showError(
            context,
            icon: TotemIcons.errorOutlined,
            title: 'Something went wrong',
            message: 'We were unable to accept the totem. Please try again.',
          );
        }

        return false;
      }
    }

    return SafeArea(
      child: ViewportResolver(
        builder: (context, viewportKind) {
          final theme = Theme.of(context);
          final selfViewMessage = selfViewEnabled
              ? 'Your self-view will stay visible during your turn. Everyone else will still see you. You can disable your camera at any time.'
              : "We'll hide your self-view during your turn so you can stay in the moment. Everyone else will still see you. You can disable your camera at any time.";
          // The receive pill already says the Totem is being passed, so
          // phones only add the self-view note next to the video.
          final selfViewNote = Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Text(
              selfViewMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          );

          final videoCard = Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: AspectRatio(
              aspectRatio: 16 / 21,
              child: localParticipant == null
                  ? const SizedBox.shrink()
                  : ParticipantCard(participant: localParticipant),
            ),
          );

          final receiveCard = ReceiveTransitionCard(
            onActionPressed: onAccept,
            keepActionLoadingOnSuccess: true,
            // Phone layouts already pad the screen by 20.
            margin: EdgeInsetsDirectional.symmetric(
              horizontal: viewportKind.isSmall ? 10 : 30,
            ),
          );
          final promptText = roundPromptText(roundPrompt);

          // Prompt, receive pill and dock read as one cluster.
          final receiveCluster = Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [?promptText, receiveCard, const SessionActionBar()],
          );

          switch (viewportKind) {
            case ViewportKind.smallPortrait:
              return Padding(
                padding: const EdgeInsetsDirectional.all(20),
                // Short phones or large text scroll the note and prompt
                // (each capped at a fifth of the height), so the video gives
                // way first and the pill and dock stay on screen.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    Widget capped(Widget child) => ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight / 5,
                      ),
                      child: SingleChildScrollView(child: child),
                    );
                    return Column(
                      spacing: 40,
                      children: [
                        capped(selfViewNote),
                        Expanded(child: videoCard),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 16,
                          children: [
                            if (promptText != null) capped(promptText),
                            receiveCard,
                            const SessionActionBar(),
                          ],
                        ),
                      ],
                    );
                  },
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
                      // Short landscape screens scroll the note and prompt
                      // and keep the pill and dock pinned, so the slider
                      // never leaves the screen (TOT-983).
                      child: Column(
                        spacing: 16,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                spacing: 16,
                                // Prompt first, so it stays next to the
                                // pill when the note fills the space.
                                children: [?promptText, selfViewNote],
                              ),
                            ),
                          ),
                          receiveCard,
                          const SessionActionBar(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            case ViewportKind.mediumSmall:
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
                    receiveCluster,
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}
