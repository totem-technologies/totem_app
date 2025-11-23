import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';
import 'package:totem_app/features/sessions/services/utils.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class MyTurn extends StatelessWidget {
  const MyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.onPassTotem,
    required this.sessionState,
    required this.event,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final Future<void> Function() onPassTotem;
  final SessionState sessionState;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    return RoomBackground(
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            final participantGrid = ParticipantLoop(
              layoutBuilder: MyTurnLayoutBuilder(isLandscape: isLandscape),
              sorting: (originalTracks) {
                return tracksSorting(
                  context: context,
                  originalTracks: originalTracks,
                  sessionState: sessionState,
                  event: event,
                );
              },
              participantTrackBuilder: (context, identifier) {
                return ParticipantCard(
                  key: getParticipantKey(identifier.participant.identity),
                  participant: identifier.participant,
                  event: event,
                );
              },
            );

            final passCard = PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () async {
                final passed = await showDialog<bool?>(
                  context: context,
                  builder: (context) {
                    return ConfirmationDialog(
                      content:
                          'Are you sure you want to pass the totem to the next '
                          'participant?',
                      confirmButtonText: 'Pass Totem',
                      type: ConfirmationDialogType.standard,
                      onConfirm: () async {
                        final navigator = Navigator.of(context);
                        try {
                          await onPassTotem();
                          if (context.mounted) {
                            navigator.pop(true);
                          }
                        } catch (error) {
                          if (context.mounted) {
                            navigator.pop(false);
                            await ErrorHandler.handleApiError(
                              context,
                              error,
                              onRetry: () async {
                                try {
                                  await onPassTotem();
                                  if (context.mounted) {
                                    showNotificationPopup(
                                      context,
                                      icon: TotemIcons.passToNext,
                                      title: 'Totem Passed',
                                      message:
                                          'The totem has been passed '
                                          'to the next participant.',
                                    );
                                  }
                                } catch (e) {
                                  // Error already handled by handleApiError
                                }
                              },
                            );
                          }
                        }
                      },
                    );
                  },
                );
                if (passed != null && passed && context.mounted) {
                  showNotificationPopup(
                    context,
                    icon: TotemIcons.passToNext,
                    title: 'Totem Passed',
                    message:
                        'The totem has been passed to the next participant.',
                  );
                }
              },
            );
            if (isLandscape) {
              return Column(
                spacing: 16,
                children: [
                  Expanded(
                    child: Row(
                      spacing: 16,
                      children: [
                        Expanded(
                          child: participantGrid,
                        ),
                        Flexible(
                          child: Column(
                            spacing: 16,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              passCard,
                              actionBar,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                spacing: 20,
                children: [
                  Expanded(child: participantGrid),
                  passCard,
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

class MyTurnLayoutBuilder implements ParticipantLayoutBuilder {
  const MyTurnLayoutBuilder({
    this.maxPerLineCount,
    this.gap = 16,
    this.isLandscape = false,
  });

  /// The amount of participants to show per line.
  ///
  /// If there are less participants than this number, it will show only the
  /// available participants.
  final int? maxPerLineCount;

  final double gap;

  final bool isLandscape;

  @override
  Widget build(
    BuildContext context,
    List<TrackWidget> children,
    List<String> pinnedTracks,
  ) {
    final itemCount = children.length;
    if (itemCount == 0) return const SizedBox.shrink();

    late final int crossAxisCount;
    if (isLandscape) {
      if (itemCount <= 2) {
        crossAxisCount = 2;
      } else if (itemCount <= 6) {
        crossAxisCount = 3;
      } else if (itemCount <= 9) {
        crossAxisCount = 4;
      } else {
        crossAxisCount = math
            .sqrt(itemCount)
            // Uses .ceil() to round up to the nearest integer.
            // This distributes the cards alongside the available space better
            // than .round() when in landscape screens.
            .ceil()
            .clamp(3, maxPerLineCount ?? 10);
      }
    } else {
      crossAxisCount = math
          .sqrt(itemCount)
          // Uses .round() to round to the nearest integer.
          // This distributes the cards alongside the available space better
          // than .ceil() when in portrait screens.
          .round()
          .clamp(1, maxPerLineCount ?? 10);
    }

    final rowCount = (itemCount / crossAxisCount).ceil();
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isLandscape ? 16 : 28,
        vertical: isLandscape ? 16 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: gap,
        children: List.generate(
          rowCount,
          (rowIndex) {
            final startIndex = rowIndex * crossAxisCount;

            return Flexible(
              child: Row(
                spacing: gap,
                children: List.generate(
                  crossAxisCount,
                  (colIndex) {
                    final itemIndex = startIndex + colIndex;
                    if (itemIndex < itemCount) {
                      return Expanded(
                        child: children[itemIndex].widget,
                      );
                    } else {
                      return const Expanded(
                        child: SizedBox.shrink(),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
