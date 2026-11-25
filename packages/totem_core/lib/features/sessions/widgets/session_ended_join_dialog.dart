import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Shown when someone taps Join Now on a Session that has already ended.
/// Points to the Space's next Session when there is one, otherwise to the
/// schedule. Cancel stays on the details page.
Future<void> showSessionEndedJoinDialog(
  BuildContext context, {
  required SessionDetailSchema session,
}) {
  final next = _nextSessionInSpace(session, DateTime.now());
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      void close() => Navigator.of(dialogContext).pop();

      void onPrimary() {
        close();
        if (next == null) {
          TotemRouter.instance.toHome(HomeRoutes.spaces);
        } else if (context.mounted) {
          unawaited(
            TotemRouter.instance.toSpaceSession(
              context,
              session.space.slug,
              next.slug,
            ),
          );
        }
      }

      return Dialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 351),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                const Center(
                  child: TotemIcon(
                    TotemIcons.clockCircle,
                    size: 60,
                    color: AppTheme.mauve,
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    'This session is no longer available to join.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.mauve,
                        foregroundColor: AppTheme.white,
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(
                        next == null
                            ? 'View other sessions'
                            : 'View next session',
                      ),
                    ),
                    TextButton(
                      onPressed: close,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.slate,
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The soonest Session of [session]'s Space that can still be signed up
/// for: not cancelled, not [session] itself, and starting after [now].
NextSessionSchema? _nextSessionInSpace(
  SessionDetailSchema session,
  DateTime now,
) {
  NextSessionSchema? next;
  for (final event in session.space.nextEvents) {
    if (event.cancelled || event.slug == session.slug) continue;
    if (!event.start.isAfter(now)) continue;
    if (next == null || event.start.isBefore(next.start)) next = event;
  }
  return next;
}
