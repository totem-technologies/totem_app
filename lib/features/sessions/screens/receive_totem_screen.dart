import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';

class ReceiveTotemScreen extends ConsumerWidget {
  const ReceiveTotemScreen({
    required this.actionBar,
    required this.onAcceptTotem,
    super.key,
  });

  final Widget actionBar;
  final Future<void> Function() onAcceptTotem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatus = ref.watch(roomStatusProvider);
    final currentSession = ref.watch(currentSessionProvider);

    return RoomBackground(
      status: sessionStatus,
      padding: const EdgeInsetsDirectional.all(20),
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            const titleWidget = SizedBox(height: 0);

            final videoCard = Padding(
              padding: const EdgeInsetsDirectional.all(20),
              child: LocalParticipantVideoCard(
                isCameraOn:
                    currentSession?.context!.room.localParticipant!
                        .isCameraEnabled() ??
                    true,
                videoTrack: currentSession?.localVideoTrack,
              ),
            );

            final passReceiveCard = TransitionCard(
              type: TotemCardTransitionType.receive,
              onActionPressed: () async {
                try {
                  await onAcceptTotem();
                  return true;
                } catch (error, stackTrace) {
                  ErrorHandler.logError(
                    error,
                    stackTrace: stackTrace,
                    message: 'Accept Totem failed',
                  );
                  if (context.mounted) {
                    showErrorPopup(
                      context,
                      icon: TotemIcons.errorOutlined,
                      title: 'Something went wrong',
                      message:
                          'We were unable to accept the totem. Please try again.',
                    );
                  }

                  return false;
                }
              },
            );

            if (isLandscape) {
              return Row(
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
                        passReceiveCard,
                        actionBar,
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                spacing: 40,
                children: [
                  titleWidget,
                  Expanded(
                    child: videoCard,
                  ),
                  passReceiveCard,
                  actionBar,
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
