// ignore_for_file: unused_element_parameter

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class MyTurn extends ConsumerStatefulWidget {
  const MyTurn({
    required this.actionBar,
    required this.onPassTotem,
    required this.event,
    super.key,
  });

  final Widget actionBar;
  final OnActionPerformed onPassTotem;
  final SessionDetailSchema event;

  @override
  ConsumerState<MyTurn> createState() => _MyTurnState();
}

class _MyTurnState extends ConsumerState<MyTurn> {
  bool _hasShownSelfViewHiddenNotice = false;

  void _showSelfViewHiddenNotice() {
    if (_hasShownSelfViewHiddenNotice || !mounted) return;
    _hasShownSelfViewHiddenNotice = true;

    showNotificationPopup(
      context,
      icon: TotemIcons.info,
      title: 'Your self-view is hidden',
      message:
          'As you share, your self-view is hidden. This is intentional, so you can settle in and speak freely.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomStatus = ref.watch(roomStatusProvider);
    final turnState = ref.watch(turnStateProvider);
    final session = ref.watch(currentSessionStateProvider);

    if (!_hasShownSelfViewHiddenNotice && turnState == TurnState.speaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSelfViewHiddenNotice();
      });
    }

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

            final nextUp = session?.speakingNextParticipant();
            final transitionType = turnState == TurnState.passing
                ? TotemCardTransitionType.waitingReceive
                : TotemCardTransitionType.pass;
            final passCard = TransitionCard(
              type: transitionType,
              onActionPressed: widget.onPassTotem,
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
                              widget.actionBar,
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
                  widget.actionBar,
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
