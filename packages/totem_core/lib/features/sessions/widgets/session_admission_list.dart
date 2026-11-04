import 'package:material_ui/material_ui.dart';

/// Display-only admission data. IDs come from the owner.
class SessionAdmissionGuest {
  const SessionAdmissionGuest({
    required this.id,
    required this.name,
    this.avatar,
  });
  final String id;
  final String name;
  final Widget? avatar;
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
      final theme = Theme.of(context);
      final rowActions = constraints.maxWidth >= 440;
      final label = switch (guests.length) {
        0 => 'No one is waiting',
        1 => '1 person',
        final n => '$n people',
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Waiting to join',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(label, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (guests.length > 1)
                TextButton(
                  onPressed: busy ? null : onAdmitAll,
                  child: const Text('Admit all'),
                ),
              IconButton(
                tooltip: 'Close admission',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          if (guests.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "You're clear. No one is waiting.",
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (var index = 0; index < guests.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _guest(context, guests[index], rowActions),
              ),
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
          child: SizedBox.square(
            dimension: 36,
            child:
                guest.avatar ??
                const CircleAvatar(child: Icon(Icons.person_outline)),
          ),
        ),
        Expanded(
          child: Text(
            guest.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: busy || onDecline == null
              ? null
              : () => onDecline!(guest.id),
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: busy || onAdmit == null ? null : () => onAdmit!(guest.id),
          child: const Text('Admit'),
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
            spacing: 4,
            children: [person, actions],
          );
  }
}
