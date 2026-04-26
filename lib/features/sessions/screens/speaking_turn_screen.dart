// ignore_for_file: unused_element_parameter

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/widgets/viewport_resolver.dart';

class SpeakingTurnScreen extends ConsumerStatefulWidget {
  const SpeakingTurnScreen({required this.event, super.key});

  final SessionDetailSchema event;

  @override
  ConsumerState<SpeakingTurnScreen> createState() => _SpeakingTurnState();
}

class _SpeakingTurnState extends ConsumerState<SpeakingTurnScreen> {
  final roundMessageController = TextEditingController();

  @override
  void dispose() {
    roundMessageController.dispose();
    super.dispose();
  }

  Future<bool> _onPassTotem([String? roundMessage]) async {
    final session = ref.read(currentSessionProvider);
    try {
      ref.read(sessionCuesServiceProvider).pulseSwipeCompletion();
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
        child: ViewportResolver(
          builder: (context, viewportKind) {
            final participantGrid = _SpeakingTurnGrid(
              event: widget.event,
              viewportKind: viewportKind,
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
                      Flexible(
                        child: TextField(
                          controller: roundMessageController,
                          decoration: const InputDecoration(
                            hintText: 'Your prompt for this round',
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 160,
                        ),
                        child: ActionSliderButton(
                          text:
                              'Pass ${nextUp != null ? 'to ${nextUp.name}' : ''}'
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
            final restingBottom = switch (viewportKind.isLarge) {
              true => 180,
              false => 80,
            };

            // Calculate how far up we need to visually push the card.
            // If the keyboard is lower than the resting position, offset is 0 (it doesn't move).
            // If the keyboard is higher, push it up by the difference.
            final double yOffset = keyboardInset > 0
                ? -math.max(0.0, (keyboardInset + 16) - restingBottom)
                : 0.0;

            switch (viewportKind) {
              case ViewportKind.smallPortrait:
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
              case ViewportKind.smallLandscape:
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
              case ViewportKind.mediumPlus:
                return Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: 60.0,
                    horizontal: 60.0,
                  ),
                  child: Column(
                    spacing: 40,
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 460,
                              maxWidth: 796,
                            ),
                            child: Center(child: participantGrid),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, yOffset),
                        child: passCard,
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

class _SpeakingTurnGrid extends ConsumerWidget {
  const _SpeakingTurnGrid({
    required this.event,
    required this.viewportKind,
    this.maxPerLineCount = 10,
    this.gap = 6,
  });

  final SessionDetailSchema event;
  final int maxPerLineCount;
  final double gap;
  final ViewportKind viewportKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantKeys = ref.watch(sessionParticipantKeysProvider);
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticipants: participants,
      state: sessionState,
    );

    // debug:
    // sortedParticipants = [for (var i = 0; i < 9; i++) ...sortedParticipants];

    final itemCount = sortedParticipants.length;
    if (itemCount == 0) return const SizedBox.shrink();

    late final int crossAxisCount;
    switch (viewportKind) {
      case ViewportKind.smallPortrait:
        crossAxisCount = math
            .sqrt(itemCount)
            // Uses .round() to round to the nearest integer.
            // This distributes the cards alongside the available space better
            // than .ceil() when in portrait screens.
            .round()
            .clamp(1, maxPerLineCount);
      case ViewportKind.smallLandscape:
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
      case ViewportKind.mediumPlus:
        if (itemCount <= 8) {
          crossAxisCount = 4;
        } else if (itemCount <= 10) {
          crossAxisCount = 5;
        } else if (itemCount <= 12) {
          crossAxisCount = 6;
        } else {
          // + 2 prefers filling out rows before adding new ones, which looks better on larger screens with more participants.
          crossAxisCount = math.sqrt(itemCount).ceil() + 2;
        }
    }

    final rowCount = (itemCount / crossAxisCount).ceil();

    return Column(
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
                        key: participantKeys.getKey(participant.sid),
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
    );
  }
}
