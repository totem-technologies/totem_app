// ignore_for_file: unused_element_parameter

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/adaptive_call_layout.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

class SpeakingTurnScreen extends ConsumerStatefulWidget {
  const SpeakingTurnScreen({required this.event, super.key});

  final SessionDetailSchema event;

  @override
  ConsumerState<SpeakingTurnScreen> createState() => _SpeakingTurnState();
}

class _SpeakingTurnState extends ConsumerState<SpeakingTurnScreen> {
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
    final roomStatus = ref.watch(roomStatusProvider);
    final turnState = ref.watch(turnStateProvider);
    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final nextUp = ref.watch(speakingNextParticipantProvider);
    final selfViewEnabled = ref.watch(selfViewEnabledProvider);

    return RoomBackground(
      status: roomStatus,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ViewportResolver(
                builder: (context, viewportKind) {
                  final participantGrid = _SpeakingTurnGrid(
                    event: widget.event,
                    viewportKind: viewportKind,
                  );

                  final isWaitingReceive = turnState == TurnState.passing;

                  final normalPassCard = isWaitingReceive
                      ? const WaitingReceiveTransitionCard()
                      : PassTransitionCard(
                          onActionPressed: _onPassTotem,
                          actionText: nextUp != null
                              ? 'Pass to ${nextUp.name}'
                              : 'Pass',
                        );

                  Widget passCard;
                  if (isWaitingReceive) {
                    passCard = normalPassCard;
                  } else if (isKeeper) {
                    passCard = PromptTransitionCard(
                      onActionPressed: (message) {
                        return _onPassTotem(
                          message.isEmpty ? null : message,
                        );
                      },
                      actionText:
                          'Pass ${nextUp != null ? 'to ${nextUp.name}' : ''}'
                              .trim(),
                    );
                  } else {
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
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.all(40.0),
                              child: participantGrid,
                            ),
                          ),
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
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.symmetric(
                                          vertical: 40.0,
                                          horizontal: 12.0,
                                        ),
                                    child: participantGrid,
                                  ),
                                ),
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
                        padding: const EdgeInsetsDirectional.only(
                          top: 40.0,
                          bottom: 28,
                          start: 60.0,
                          end: 60.0,
                        ),
                        child: Column(
                          spacing: 40,
                          children: [
                            Expanded(
                              child: Center(
                                child: Center(child: participantGrid),
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
            if (selfViewEnabled) const _SelfView(),
          ],
        ),
      ),
    );
  }
}

/// The grid layout for the speaking turn screen.
///
/// When in a small screen, the grid is controlled.
///
/// When in a large screen, the grid is an adaptive layout.
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
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider)!;

    final sortedParticipants = participantsSorting(
      originalParticipants: participants,
      state: sessionState,
      showSpeakingNow: false,
    );

    // debug:
    // sortedParticipants = [for (var i = 0; i < 13; i++) ...sortedParticipants];

    return ViewportResolver(
      builder: (context, viewportKind) {
        switch (viewportKind) {
          case ViewportKind.smallPortrait:
          case ViewportKind.smallLandscape:
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
              case ViewportKind.mediumPlus:
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
                                key: ValueKey(participant.sid),
                                participant: participant,
                                session: event,
                                participantIdentity: participant.identity,
                              ),
                            );
                          } else {
                            return const Expanded(child: SizedBox.shrink());
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          case ViewportKind.mediumPlus:
            return AdaptiveCallLayout(
              participants: [
                for (final participant in sortedParticipants)
                  ParticipantCard(
                    key: ValueKey(participant.sid),
                    participant: participant,
                    session: event,
                    participantIdentity: participant.identity,
                  ),
              ],
            );
        }
      },
    );
  }
}

enum SelfViewPosition { start, end }

/// A floating self-view that shows the current participant's video.
///
/// Draggable horizontally; snaps to [SelfViewPosition.start] (top-left) or
/// [SelfViewPosition.end] (top-right).
class _SelfView extends ConsumerStatefulWidget {
  const _SelfView();

  @override
  ConsumerState<_SelfView> createState() => _SelfViewState();
}

class _SelfViewState extends ConsumerState<_SelfView>
    with SingleTickerProviderStateMixin {
  SelfViewPosition _position = SelfViewPosition.start;

  Offset _visualOffset = Offset.zero;
  late final AnimationController _snapController;

  static const double _cardWidth = 70;
  // Aspect ratio is 3/4, so height is 70 * (4 / 3) = 56.67
  static const double _cardHeight = _cardWidth * (4 / 3);
  static const double _padding = 16;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  // Helper to get the top-left or top-right snap position
  Offset get _targetPosition {
    final screenWidth = MediaQuery.of(context).size.width;
    final left = _position == SelfViewPosition.start
        ? _padding
        : screenWidth - _cardWidth - _padding;

    // Always snaps to the top padding
    return Offset(left, _padding);
  }

  void _onPanStart(DragStartDetails details) {
    _snapController.stop();
    setState(() {
      // Bake the current animation state into the 2D offset
      _visualOffset = _visualOffset * (1 - _snapController.value);
      _snapController.value = 0;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final size = MediaQuery.of(context).size;
    final currentPos = _targetPosition + _visualOffset + details.delta;

    // Clamp to screen bounds on both X and Y axes
    final clampedX = currentPos.dx.clamp(0.0, size.width - _cardWidth);
    final clampedY = currentPos.dy.clamp(0.0, size.height - _cardHeight);

    setState(() {
      _visualOffset = Offset(clampedX, clampedY) - _targetPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final currentPos = _targetPosition + _visualOffset;

    final midpoint = screenWidth / 2;
    final newPosition = currentPos.dx + _cardWidth / 2 < midpoint
        ? SelfViewPosition.start
        : SelfViewPosition.end;

    final newTargetLeft = newPosition == SelfViewPosition.start
        ? _padding
        : screenWidth - _cardWidth - _padding;
    final newTargetPosition = Offset(newTargetLeft, _padding);

    final remainingOffset = currentPos - newTargetPosition;

    setState(() {
      _position = newPosition;
      _visualOffset = remainingOffset;
    });

    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    final participants = ref.watch(sessionParticipantsProvider);
    final participantKeys = ref.watch(sessionParticipantKeysProvider);
    final currentParticipant = participants.firstWhereOrNull(
      (p) => p.identity == currentUserSlug,
    );

    if (currentParticipant == null) return const SizedBox.shrink();

    final child = SizedBox(
      width: _cardWidth,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: GestureDetector(
          // Swapped horizontal drag for pan gestures
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(width: 1.5, color: AppTheme.blue),
              boxShadow: kElevationToShadow[6],
            ),
            position: DecorationPosition.foreground,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: ParticipantVideo(
                      key: participantKeys.getKey(currentParticipant.sid),
                      participant: currentParticipant,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      'You',
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Dart's Offset class supports scalar multiplication out of the box
    final offset = _visualOffset * (1 - _snapController.value);
    final target = _targetPosition;

    return Positioned(
      top: target.dy + offset.dy,
      left: target.dx + offset.dx,
      child: child,
    );
  }
}
