import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/layout/layout.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';

class NotMyTurn extends ConsumerWidget {
  const NotMyTurn({
    required this.getParticipantKey,
    required this.actionBar,
    required this.sessionState,
    required this.event,
    super.key,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final SessionState sessionState;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomCtx = RoomContext.of(context)!;
    final speakingNow = roomCtx.participants.firstWhere(
      (participant) {
        if (sessionState.speakingNow != null) {
          return participant.identity == sessionState.speakingNow;
        }
        return participant.isSpeaking;
      },
      orElse: () => roomCtx.localParticipant!,
    );

    return RoomBackground(
      child: AdaptiveLayout(
        mobilePortrait: _NotMyTurnPortrait(
          getParticipantKey: getParticipantKey,
          actionBar: actionBar,
          event: event,
          speakingNow: speakingNow,
        ),
        mobileLandscape: _NotMyTurnLandscape(
          getParticipantKey: getParticipantKey,
          actionBar: actionBar,
          event: event,
          speakingNow: speakingNow,
        ),
      ),
    );
  }
}

/// Portrait layout for NotMyTurn screen
class _NotMyTurnPortrait extends StatelessWidget {
  const _NotMyTurnPortrait({
    required this.getParticipantKey,
    required this.actionBar,
    required this.event,
    required this.speakingNow,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final EventDetailSchema event;
  final Participant speakingNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layoutInfo = context.layoutInfo;

    final speakerVideo = ClipRRect(
      borderRadius: const BorderRadiusDirectional.vertical(
        bottom: Radius.circular(30),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppTheme.blue),
        child: Stack(
          children: [
            Positioned.fill(
              child: ParticipantVideo(participant: speakingNow),
            ),
            PositionedDirectional(
              end: 30,
              bottom: 30,
              child: Text(
                speakingNow.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    const Shadow(blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final participantGrid = ParticipantLoop(
      layoutBuilder: NoMyTurnLayoutBuilder(
        layoutInfo: layoutInfo,
      ),
      participantTrackBuilder: (context, identifier) {
        return ParticipantCard(
          key: getParticipantKey(identifier.participant.identity),
          participant: identifier.participant,
          event: event,
        );
      },
    );

    return SafeArea(
      top: false,
      child: Column(
        spacing: 20,
        children: [
          Expanded(
            flex: 2,
            child: speakerVideo,
          ),
          Flexible(child: participantGrid),
          actionBar,
        ],
      ),
    );
  }
}

/// Landscape layout for NotMyTurn screen
class _NotMyTurnLandscape extends StatelessWidget {
  const _NotMyTurnLandscape({
    required this.getParticipantKey,
    required this.actionBar,
    required this.event,
    required this.speakingNow,
  });

  final GlobalKey Function(String) getParticipantKey;
  final Widget actionBar;
  final EventDetailSchema event;
  final Participant speakingNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layoutInfo = context.layoutInfo;
    final spacing = layoutInfo.gridSpacing;

    final speakerVideo = ClipRRect(
      borderRadius: const BorderRadiusDirectional.horizontal(
        end: Radius.circular(30),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppTheme.blue),
        child: Stack(
          children: [
            Positioned.fill(
              child: ParticipantVideo(participant: speakingNow),
            ),
            PositionedDirectional(
              end: 30,
              bottom: 30,
              child: Text(
                speakingNow.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    const Shadow(blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final participantGrid = ParticipantLoop(
      layoutBuilder: NoMyTurnLayoutBuilder(
        isLandscape: true,
        layoutInfo: layoutInfo,
      ),
      participantTrackBuilder: (context, identifier) {
        return ParticipantCard(
          key: getParticipantKey(identifier.participant.identity),
          participant: identifier.participant,
          event: event,
        );
      },
    );

    final isLTR = Directionality.of(context) == TextDirection.ltr;
    return SafeArea(
      top: false,
      left: !isLTR,
      right: isLTR,
      child: Row(
        spacing: spacing,
        children: [
          Expanded(
            child: speakerVideo,
          ),
          Expanded(
            child: Column(
              spacing: spacing,
              children: [
                Expanded(child: participantGrid),
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: layoutInfo.horizontalPadding,
                  ),
                  child: actionBar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoMyTurnLayoutBuilder implements ParticipantLayoutBuilder {
  const NoMyTurnLayoutBuilder({
    required this.layoutInfo,
    this.maxPerLineCount,
    this.gap = 10,
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
    final itemCount = children.length;
    int crossAxisCount;
    double childAspectRatio;

    if (isLandscape) {
      // Optimize for landscape: fewer columns, more rows
      if (itemCount <= 2) {
        crossAxisCount = 2;
      } else if (itemCount <= 4) {
        crossAxisCount = 2;
      } else if (itemCount <= 6) {
        crossAxisCount = 3;
      } else {
        crossAxisCount = 3;
      }
      childAspectRatio = 16 / 21;
    } else {
      // Portrait orientation logic
      if (itemCount <= 3) {
        crossAxisCount = 3;
      } else if (itemCount <= 5) {
        crossAxisCount = itemCount;
      } else if (itemCount <= 10) {
        crossAxisCount = (itemCount / 2).ceil();
      } else {
        crossAxisCount = 5;
      }
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
        physics: const AlwaysScrollableScrollPhysics(),
        children: List.generate(
          itemCount,
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
  }
}
