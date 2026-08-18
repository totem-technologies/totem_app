import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/shared/assets.dart';
import 'package:totem_core/shared/date.dart';
import 'package:totem_core/shared/network.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

Future<bool?> showConflictingSessionsDialog(
  BuildContext context,
  SessionConflictSchema conflict,
  SessionDetailSchema newSession,
  AsyncValueGetter<bool> onSwitch,
) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => ConflictingSessionsDialog(
      conflict: conflict,
      newSession: newSession,
      onSwitch: onSwitch,
    ),
  );
}

class ConflictingSessionsDialog extends StatelessWidget {
  final SessionConflictSchema conflict;
  final SessionDetailSchema newSession;
  final AsyncValueGetter<bool> onSwitch;

  const ConflictingSessionsDialog({
    super.key,
    required this.conflict,
    required this.newSession,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return ConfirmationDialog(
      title: 'You have another session at this time.',
      content:
          'To join ${newSession.title}, you’ll need to give up your spot in ${conflict.conflictingSessions.map((e) => e.title).join(', ')}.',
      icon: TotemIcons.calendar,
      iconSize: 32,
      type: ConfirmationDialogType.standard,
      scrollable: true,
      contentWidget: _SessionCardsLayout(
        existingSessions: conflict.conflictingSessions,
        newSession: newSession,
      ),
      confirmButtonText: 'Switch Sessions',
      onConfirm: () async {
        final switched = await onSwitch();
        if (switched && context.mounted) {
          Navigator.of(context).pop(true);
        }
      },
    );
  }
}

enum _SessionCardType { existing, newSession }

class _SessionCardsLayout extends StatelessWidget {
  const _SessionCardsLayout({
    required this.existingSessions,
    required this.newSession,
  });

  static const _minimumColumnViewportHeight = 600.0;

  final List<SessionDetailSchema> existingSessions;
  final SessionDetailSchema newSession;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final usableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.vertical;
    final horizontal =
        mediaQuery.orientation == Orientation.landscape ||
        usableHeight < _minimumColumnViewportHeight;

    Widget card(SessionDetailSchema session, _SessionCardType type) {
      final child = _SessionCard(
        session: session,
        type: type,
        compact: horizontal,
      );
      return horizontal ? Expanded(child: child) : child;
    }

    return Flex(
      key: ValueKey(
        horizontal
            ? 'conflicting-sessions-horizontal-layout'
            : 'conflicting-sessions-vertical-layout',
      ),
      direction: horizontal ? Axis.horizontal : Axis.vertical,
      mainAxisSize: horizontal ? MainAxisSize.max : MainAxisSize.min,
      spacing: 6,
      children: [
        for (final session in existingSessions)
          card(session, _SessionCardType.existing),
        RotatedBox(
          quarterTurns: horizontal ? 2 : -1,
          child: const TotemIcon(TotemIcons.arrowBack, size: 18),
        ),
        card(newSession, _SessionCardType.newSession),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.type,
    required this.compact,
  });

  final SessionDetailSchema session;
  final _SessionCardType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = session.space.imageLink;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFAEEFF),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          SizedBox(
            width: compact ? 60 : 100,
            height: double.infinity,
            // TODO(totem): Create a TotemSpaceImage widget.
            // This code is reflected in a lot of places in the codebase. This can be extracted and remove boilerplates
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: getFullUrl(imageUrl),
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade200),
                    errorWidget: (context, url, error) => Image.asset(
                      TotemImageAssets.genericBackground,
                      fit: BoxFit.cover,
                      package: 'totem_core',
                    ),
                  )
                : Image.asset(
                    TotemImageAssets.genericBackground,
                    fit: BoxFit.cover,
                    package: 'totem_core',
                  ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: compact ? 6 : 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(switch (type) {
                    _SessionCardType.existing => 'Your current session',
                    _SessionCardType.newSession => 'New session',
                  }, style: theme.textTheme.labelSmall),
                  Text(
                    session.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${formatSessionDate(session.start)} '
                    '${formatSessionTime(session.start)}',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
