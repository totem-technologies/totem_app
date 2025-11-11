import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/layout/layout.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';

class MyTurn extends StatelessWidget {
  const MyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.onPassTotem,
    required this.event,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final Future<void> Function() onPassTotem;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    return RoomBackground(
      child: SafeArea(
        child: AdaptiveLayout(
          mobilePortrait: _MyTurnPortrait(
            getParticipantKey: getParticipantKey,
            actionBar: actionBar,
            onPassTotem: onPassTotem,
            event: event,
          ),
          mobileLandscape: _MyTurnLandscape(
            getParticipantKey: getParticipantKey,
            actionBar: actionBar,
            onPassTotem: onPassTotem,
            event: event,
          ),
        ),
      ),
    );
  }
}

/// Portrait layout for MyTurn screen
class _MyTurnPortrait extends StatelessWidget {
  const _MyTurnPortrait({
    required this.getParticipantKey,
    required this.actionBar,
    required this.onPassTotem,
    required this.event,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final Future<void> Function() onPassTotem;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final layoutInfo = context.layoutInfo;

    final participantGrid = ParticipantLoop(
      layoutBuilder: MyTurnLayoutBuilder(
        layoutInfo: layoutInfo,
      ),
      participantTrackBuilder: (context, identifier) {
        return ParticipantCard(
          key: getParticipantKey(
            identifier.participant.identity,
          ),
          participant: identifier.participant,
          event: event,
        );
      },
    );

    final passCard = PassReceiveCard(
      type: TotemCardTransitionType.pass,
      onActionPressed: () async {
        await showDialog<void>(
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
                await onPassTotem();
                navigator.pop();
              },
            );
          },
        );
      },
    );

    return Column(
      spacing: 20,
      children: [
        Expanded(child: participantGrid),
        passCard,
        actionBar,
      ],
    );
  }
}

/// Landscape layout for MyTurn screen
class _MyTurnLandscape extends StatelessWidget {
  const _MyTurnLandscape({
    required this.getParticipantKey,
    required this.actionBar,
    required this.onPassTotem,
    required this.event,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final Future<void> Function() onPassTotem;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final layoutInfo = context.layoutInfo;
    final spacing = layoutInfo.gridSpacing;

    final participantGrid = ParticipantLoop(
      layoutBuilder: MyTurnLayoutBuilder(
        isLandscape: true,
        layoutInfo: layoutInfo,
      ),
      participantTrackBuilder: (context, identifier) {
        return ParticipantCard(
          key: getParticipantKey(
            identifier.participant.identity,
          ),
          participant: identifier.participant,
          event: event,
        );
      },
    );

    final passCard = PassReceiveCard(
      type: TotemCardTransitionType.pass,
      onActionPressed: () async {
        await showDialog<void>(
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
                await onPassTotem();
                navigator.pop();
              },
            );
          },
        );
      },
    );

    return Column(
      spacing: spacing,
      children: [
        Expanded(
          child: Row(
            spacing: spacing,
            children: [
              Expanded(
                child: participantGrid,
              ),
              Flexible(
                child: Column(
                  spacing: spacing,
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
  }
}

class MyTurnLayoutBuilder implements ParticipantLayoutBuilder {
  const MyTurnLayoutBuilder({
    required this.layoutInfo,
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

  final LayoutInfo layoutInfo;

  @override
  Widget build(
    BuildContext context,
    List<TrackWidget> children,
    List<String> pinnedTracks,
  ) {
    // TODO(bdlukaa): Handle more than 16 participants
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = children.length;
        int crossAxisCount;
        double childAspectRatio;

        if (isLandscape) {
          // Optimize landscape: more columns, better use of horizontal space
          if (itemCount <= 2) {
            crossAxisCount = 2;
          } else if (itemCount <= 6) {
            crossAxisCount = 3;
          } else if (itemCount <= 9) {
            crossAxisCount = 4;
          } else {
            crossAxisCount = math
                .sqrt(itemCount)
                .ceil()
                .clamp(3, maxPerLineCount ?? 4);
          }
          childAspectRatio = 16 / 21;
        } else {
          // Portrait orientation logic
          crossAxisCount = math
              .sqrt(itemCount)
              .ceil()
              .clamp(
                1,
                maxPerLineCount ?? 10,
              );
          childAspectRatio = 16 / 21;
        }

        return Center(
          child: GridView.count(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: layoutInfo.horizontalPadding,
              vertical: layoutInfo.verticalPadding,
            ),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: childAspectRatio,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              children.length,
              (index) {
                if (index < children.length) {
                  return children[index].widget;
                } else {
                  return SizedBox.shrink(key: ValueKey<int>(index));
                }
              },
            ),
          ),
        );
      },
    );
  }
}
