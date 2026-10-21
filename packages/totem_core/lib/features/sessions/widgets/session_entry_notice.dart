import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

/// Contents of an entry sheet or modal; the caller owns its visibility.
class SessionEntryNotice extends StatelessWidget {
  const SessionEntryNotice({
    required this.kicker,
    required this.title,
    required this.children,
    required this.onDone,
    super.key,
    this.doneLabel = 'Got it',
  });

  final String kicker;
  final String title;
  final List<Widget> children;
  final VoidCallback? onDone;
  final String doneLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Modal content is narrow even in a desktop window.
      final wide = MediaQuery.sizeOf(context).width >= 640;
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(
            kicker.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.5,
              letterSpacing: 0.8,
              color: entryMauve,
            ),
          ),
          Semantics(header: true, child: Text(title, style: entrySubtitle)),
          ...children,
          if (wide)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 140),
              child: SessionEntryAction(label: doneLabel, onPressed: onDone),
            )
          else
            SessionEntryAction(
              label: doneLabel,
              onPressed: onDone,
              expand: true,
            ),
        ],
      );
      return constraints.hasBoundedHeight
          ? SingleChildScrollView(child: content)
          : content;
    },
  );
}

/// Late-join orientation content. [prompt] is supplied by the live Session;
/// an absent prompt is not replaced with a fixture.
class SessionOrientationNotice extends StatelessWidget {
  const SessionOrientationNotice({
    required this.onDone,
    super.key,
    this.prompt,
  });

  final String? prompt;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => SessionEntryNotice(
    kicker: 'Joining',
    title: "You're joining a session already in progress.",
    onDone: onDone,
    children: [
      if (prompt != null && prompt!.isNotEmpty) ...[
        const Text(
          'CURRENT PROMPT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.48,
            color: Color(0xFF787D7E),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: entryCream,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(prompt!, style: entrySubtitle),
        ),
      ],
      const Text(
        "You'll receive the talking piece when it's your turn to share.",
        style: entryMuted,
      ),
    ],
  );
}
