// ignore_for_file: unused_element_parameter

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

class MyTurn extends ConsumerWidget {
  const MyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.onPassTotem,
    required this.event,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final OnActionPerformed onPassTotem;
  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatus = ref.watch(sessionStatusProvider);
    final totemStatus = ref.watch(totemStatusProvider);
    final currentSession = ref.watch(currentSessionProvider);

    return RoomBackground(
      status: sessionStatus,
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            final participantGrid = _MyTurnGrid(
              isLandscape: isLandscape,
              getParticipantKey: getParticipantKey,
              event: event,
            );

            final nextUp = currentSession?.speakingNextParticipant();
            final transitionType = totemStatus == TotemStatus.passing
                ? TotemCardTransitionType.waitingReceive
                : TotemCardTransitionType.pass;
            final passCard = TransitionCard(
              type: transitionType,
              onActionPressed: onPassTotem,
              actionText:
                  nextUp != null &&
                      transitionType == TotemCardTransitionType.pass
                  ? 'Pass to ${nextUp.name}'
                  : null,
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

class _MyTurnGrid extends ConsumerWidget {
  const _MyTurnGrid({
    required this.isLandscape,
    required this.getParticipantKey,
    required this.event,
    this.maxPerLineCount = 10,
    this.gap = 6,
  });

  final bool isLandscape;
  final GlobalKey Function(String) getParticipantKey;
  final SessionDetailSchema event;
  final int maxPerLineCount;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticiapnts: participants,
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
                          key: getParticipantKey(participant.identity),
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
