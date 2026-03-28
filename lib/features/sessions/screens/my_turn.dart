// ignore_for_file: unused_element_parameter

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

class MyTurn extends ConsumerStatefulWidget {
  const MyTurn({required this.event, super.key});

  final SessionDetailSchema event;

  @override
  ConsumerState<MyTurn> createState() => _MyTurnState();
}

class _MyTurnState extends ConsumerState<MyTurn> {
  final roundMessageController = TextEditingController();

  @override
  void dispose() {
    roundMessageController.dispose();
    super.dispose();
  }

  Future<bool> _onPassTotem([String? roundMessage]) async {
    final session = ref.read(currentSessionProvider);
    try {
      await session?.keeper.passTotem(roundMessage: roundMessage);
      return true;
    } catch (error) {
      if (!mounted) return false;
      ErrorHandler.handleApiError(context, error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomStatus = ref.watch(roomStatusProvider);
    final turnState = ref.watch(turnStateProvider);
    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final nextUp = ref.watch(speakingNextParticipantProvider);

    return RoomBackground(
      status: roomStatus,
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            final participantGrid = _MyTurnGrid(
              isLandscape: isLandscape,
              event: widget.event,
            );

            final transitionType = turnState == TurnState.passing
                ? TotemCardTransitionType.waitingReceive
                : TotemCardTransitionType.pass;

            final normalPassCard = TransitionCard(
              type: transitionType,
              onActionPressed: _onPassTotem,
              actionText:
                  nextUp != null &&
                      transitionType == TotemCardTransitionType.pass
                  ? 'Pass to ${nextUp.name}'
                  : null,
            );
            Widget passCard;
            switch (transitionType) {
              case TotemCardTransitionType.pass:
                if (isKeeper) {
                  passCard = TransitionCardContainer(
                    children: [
                      TextField(
                        controller: roundMessageController,
                        decoration: const InputDecoration(
                          hintText: 'Your prompt for this round',
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 160,
                        ),
                        child: ActionSlider(
                          text:
                              'Slide to pass ${nextUp != null ? 'to ${nextUp.name}' : ''}'
                                  .trim(),
                          onActionCompleted: () {
                            final roundMessage = roundMessageController.text
                                .trim();
                            return _onPassTotem(
                              roundMessage.isEmpty ? null : roundMessage,
                            );
                          },
                          keepLoadingOnSuccess: true,
                        ),
                      ),
                    ],
                  );
                } else {
                  passCard = normalPassCard;
                }
              case TotemCardTransitionType.waitingReceive:
              default:
                passCard = normalPassCard;
            }
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final restingBottom = switch (isLandscape) {
              true => 180,
              false => 80,
            };

            // Calculate how far up we need to visually push the card.
            // If the keyboard is lower than the resting position, offset is 0 (it doesn't move).
            // If the keyboard is higher, push it up by the difference.
            final double yOffset = keyboardInset > 0
                ? -math.max(0.0, (keyboardInset + 16) - restingBottom)
                : 0.0;
            if (isLandscape) {
              return Column(
                spacing: 16,
                children: [
                  Expanded(
                    child: Row(
                      spacing: 16,
                      children: [
                        Expanded(child: participantGrid),
                        Flexible(
                          child: Column(
                            spacing: 16,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                offset: Offset(0, yOffset),
                                child: passCard,
                              ),
                              const SessionActionBar(),
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
                  Transform.translate(
                    offset: Offset(0, yOffset),
                    child: passCard,
                  ),
                  const SessionActionBar(),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

class _MyTurnGrid extends ConsumerWidget {
  const _MyTurnGrid({
    required this.isLandscape,
    required this.event,
    this.maxPerLineCount = 10,
    this.gap = 6,
  });

  final bool isLandscape;
  final SessionDetailSchema event;
  final int maxPerLineCount;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantKeys = ref.watch(sessionParticipantKeysProvider);
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticipants: participants,
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
            .clamp(3, maxPerLineCount);
      }
    } else {
      crossAxisCount = math
          .sqrt(itemCount)
          // Uses .round() to round to the nearest integer.
          // This distributes the cards alongside the available space better
          // than .ceil() when in portrait screens.
          .round()
          .clamp(1, maxPerLineCount);
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
                      final participant = sortedParticipants[itemIndex];
                      return Expanded(
                        child: ParticipantCard(
                          key: participantKeys.getKey(participant.identity),
                          participant: participant,
                          session: event,
                          participantIdentity: participant.identity,
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
