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
  Widget build(BuildContext context) {
    final promptText = prompt?.trim();
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const Text(
          "You're joining a session already in progress. You'll receive the talking piece when it's your turn to share.",
          style: entryBody,
        ),
        if (promptText != null && promptText.isNotEmpty)
          Text.rich(
            TextSpan(
              text: 'Current prompt: ',
              style: entryMuted.copyWith(fontWeight: FontWeight.w600),
              children: [TextSpan(text: promptText, style: entryMuted)],
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          if (constraints.hasBoundedHeight)
            Flexible(child: SingleChildScrollView(child: content))
          else
            content,
          SessionEntryAction(
            label: 'Got it',
            onPressed: onDone,
            expand: MediaQuery.sizeOf(context).width < 640,
          ),
        ],
      ),
    );
  }
}
