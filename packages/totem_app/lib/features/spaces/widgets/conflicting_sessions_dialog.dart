import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:totem_core/core/api/api_client/models/session_detail_schema.dart';
import 'package:totem_core/shared/assets.dart';
import 'package:totem_core/shared/date.dart';
import 'package:totem_core/shared/network.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

Future<bool?> showConflictingSessionsDialog(
  BuildContext context,
  SessionDetailSchema existingSession,
  SessionDetailSchema newSession,
  Future<bool> Function() onSwitch,
) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => ConflictingSessionsDialog(
      existingSession: existingSession,
      newSession: newSession,
      onSwitch: onSwitch,
    ),
  );
}

class ConflictingSessionsDialog extends StatelessWidget {
  final SessionDetailSchema existingSession;
  final SessionDetailSchema newSession;
  final Future<bool> Function() onSwitch;

  const ConflictingSessionsDialog({
    super.key,
    required this.existingSession,
    required this.newSession,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return ConfirmationDialog(
      title: 'You have another session at this time.',
      content:
          'To join ${newSession.title}, you’ll need to give up your spot in ${existingSession.title}.',
      icon: TotemIcons.calendar,
      iconSize: 32,
      type: ConfirmationDialogType.standard,
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          _SessionCard(
            session: existingSession,
            type: _SessionCardType.existing,
          ),
          const RotatedBox(
            quarterTurns: 1,
            child: TotemIcon(TotemIcons.arrowBack, size: 18),
          ),
          _SessionCard(session: newSession, type: _SessionCardType.newSession),
        ],
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.type});

  final SessionDetailSchema session;
  final _SessionCardType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = session.space.imageLink;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFAEEFF),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          SizedBox(
            width: 90,
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
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 1,
                children: [
                  Text(switch (type) {
                    _SessionCardType.existing => 'Your existing session:',
                    _SessionCardType.newSession => 'New session:',
                  }, style: theme.textTheme.labelSmall),
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    formatShortDate(session.start),
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
