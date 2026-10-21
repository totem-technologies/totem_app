import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

/// Display-only admission data. IDs and expiration labels come from the owner.
class SessionAdmissionGuest {
  const SessionAdmissionGuest({
    required this.id,
    required this.name,
    required this.expiresLabel,
  });
  final String id;
  final String name;
  final String expiresLabel;
}

/// Contents of the keeper's admission sheet or side panel. The caller owns
/// the queue, decisions, busy state, and the surface that presents this list.
class SessionAdmissionList extends StatelessWidget {
  const SessionAdmissionList({
    required this.guests,
    super.key,
    this.onAdmit,
    this.onDecline,
    this.onAdmitAll,
    this.onClose,
    this.busy = false,
  });

  final List<SessionAdmissionGuest> guests;
  final ValueChanged<String>? onAdmit;
  final ValueChanged<String>? onDecline;
  final VoidCallback? onAdmitAll;
  final VoidCallback? onClose;
  final bool busy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The desktop drawer is only 360px wide; decide based on content width.
      final rowActions = constraints.maxWidth >= 440;
      final label = switch (guests.length) {
        0 => 'No one is waiting',
        1 => '1 person',
        final n => '$n people',
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: const Text(
                        'Waiting to join',
                        style: entrySubtitle,
                      ),
                    ),
                    Text(label, style: entryMuted),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close admission',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x14262F37),
                  foregroundColor: entrySlate,
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
          if (guests.isEmpty)
            const Text("You're clear. No one is waiting.", style: entryMuted)
          else ...[
            if (guests.length > 1)
              SessionEntryAction(
                label: 'Admit all',
                onPressed: busy ? null : onAdmitAll,
                expand: true,
              ),
            for (final guest in guests) _guest(context, guest, rowActions),
          ],
        ],
      );
    },
  );

  Widget _guest(
    BuildContext context,
    SessionAdmissionGuest guest,
    bool rowActions,
  ) {
    final person = Row(
      spacing: 12,
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 20,
            backgroundColor: entryMauve,
            child: Text(
              guest.name.isEmpty
                  ? ''
                  : guest.name.substring(0, 1).toUpperCase(),
              style: entryBody.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guest.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: entryBody.copyWith(fontWeight: FontWeight.w600),
              ),
              Text('Expires in ${guest.expiresLabel}', style: entryMuted),
            ],
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: rowActions ? MainAxisSize.min : MainAxisSize.max,
      spacing: 8,
      children: [
        if (rowActions)
          SessionEntryAction(
            label: 'Decline',
            onPressed: busy || onDecline == null
                ? null
                : () => onDecline!(guest.id),
            secondary: true,
            compact: true,
          )
        else
          Expanded(
            child: SessionEntryAction(
              label: 'Decline',
              onPressed: busy || onDecline == null
                  ? null
                  : () => onDecline!(guest.id),
              secondary: true,
              compact: true,
              expand: true,
            ),
          ),
        if (rowActions)
          SessionEntryAction(
            label: 'Admit',
            onPressed: busy || onAdmit == null
                ? null
                : () => onAdmit!(guest.id),
            compact: true,
          )
        else
          Expanded(
            child: SessionEntryAction(
              label: 'Admit',
              onPressed: busy || onAdmit == null
                  ? null
                  : () => onAdmit!(guest.id),
              compact: true,
              expand: true,
            ),
          ),
      ],
    );
    return rowActions
        ? Row(
            spacing: 12,
            children: [
              Expanded(child: person),
              actions,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [person, actions],
          );
  }
}
