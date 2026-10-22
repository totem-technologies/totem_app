import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

/// A display fact supplied by the session owner; [icon] may be any host icon.
class SessionEntryFact {
  const SessionEntryFact({
    required this.icon,
    required this.label,
    this.value = '',
  });
  final Widget icon;
  final String label;
  final String value;
}

/// Session timing, facts, and join action shown before entering the lobby.
/// No session, admission, or availability state is inferred here.
class SessionEntryInfoCard extends StatelessWidget {
  const SessionEntryInfoCard({
    required this.facts,
    required this.dateLabel,
    required this.timeLabel,
    required this.onJoin,
    super.key,
  });

  final List<SessionEntryFact> facts;
  final String dateLabel;
  final String timeLabel;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Semantics(
      container: true,
      label: 'Session info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 17,
        children: [
          if (facts.isNotEmpty) _factGrid(),
          LayoutBuilder(
            builder: (context, constraints) {
              final time = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entrySlate,
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: entryMuted.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
              final join = SessionEntryAction(
                label: 'Join session',
                onPressed: onJoin,
                compact: true,
              );
              if (constraints.maxWidth < 260) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [time, join],
                );
              }
              return Row(
                spacing: 9,
                children: [
                  Expanded(child: time),
                  join,
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _factGrid() {
    const columns = 3;
    final rows = <TableRow>[];
    for (var i = 0; i < facts.length; i += columns) {
      final slice = facts.skip(i).take(columns).toList();
      rows.add(
        TableRow(
          children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                child: j < slice.length
                    ? _fact(slice[j])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {1: FlexColumnWidth(), 3: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  Widget _fact(SessionEntryFact fact) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      fact.icon,
      Flexible(
        child: Text.rich(
          TextSpan(
            children: [
              if (fact.value.isNotEmpty) TextSpan(text: '${fact.value} '),
              TextSpan(
                text: fact.label,
                style: fact.value.isEmpty
                    ? null
                    : const TextStyle(color: Color(0xB3262F37)),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: entrySlate,
          ),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
