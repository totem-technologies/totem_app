import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/totem_icons.dart';
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
  final SessionRoomState sessionState;
  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context) {
    return RoomBackground(
      status: sessionState.sessionState.status,
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            final participantGrid = MyTurnGrid(
              sessionState: sessionState,
              isLandscape: isLandscape,
              buildParticipant: (context, participant) {
                return ParticipantCard(
                  key: getParticipantKey(participant.identity),
                  participant: participant,
                  event: event,
                  participantIdentity: participant.identity,
                );
              },
            );

            final passCard = TransitionCard(
              type: sessionState.sessionState.totemStatus == TotemStatus.passing
                  ? TotemCardTransitionType.waitingReceive
                  : TotemCardTransitionType.pass,
              onActionPressed: () async {
                try {
                  await onPassTotem();
                  if (context.mounted) {
                    showNotificationPopup(
                      context,
                      icon: TotemIcons.passToNext,
                      title: 'Totem Passed',
                      message:
                          'The totem has been passed to the next participant.',
                    );
                  }
                  return true;
                } catch (error) {
                  if (context.mounted) {
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

                return false;
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

class MyTurnGrid extends StatelessWidget {
  const MyTurnGrid({
    required this.sessionState,
    required this.buildParticipant,
    this.maxPerLineCount,
    this.gap = 6,
    this.isLandscape = false,
    super.key,
  });

  /// The amount of participants to show per line.
  ///
  /// If there are less participants than this number, it will show only the
  /// available participants.
  final int? maxPerLineCount;

  /// The gap between participants.
  final double gap;

  /// Whether the layout is in landscape mode.
  final bool isLandscape;

  /// The session state.
  final SessionRoomState sessionState;

  final Widget Function(BuildContext context, Participant participant)
  buildParticipant;

  @override
  Widget build(BuildContext context) {
    final sortedParticipants = participantsSorting(
      originalParticiapnts: sessionState.participants,
      state: sessionState,
    );
    final itemCount = sortedParticipants.length;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          rowCount,
          (rowIndex) {
            final startIndex = rowIndex * crossAxisCount;

            return Flexible(
              child: Row(
                spacing: gap,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  crossAxisCount,
                  (colIndex) {
                    final itemIndex = startIndex + colIndex;
                    if (itemIndex < itemCount) {
                      return Expanded(
                        child: Builder(
                          builder: (context) {
                            return buildParticipant(
                              context,
                              sortedParticipants[itemIndex],
                            );
                          },
                        ),
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
