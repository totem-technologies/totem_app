import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

/// Data and action for the lobby, or a passive admitted-before-start card.
class SessionWaitingCard extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 366),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(title, textAlign: TextAlign.center, style: entryTitle),
          DefaultTextStyle(
            style: entryBody.copyWith(height: 1.2),
            textAlign: TextAlign.center,
            child: body,
          ),
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SessionEntryAction(
                label: actionLabel!,
                onPressed: onAction,
                secondary: true,
                expand: true,
              ),
            ),
        ],
      ),
    ),
  );
}

/// Presentational waiting shell. Supply a real local preview and media controls;
/// this widget never creates a room, camera track, or admission request.
class SessionWaitingView extends StatelessWidget {
  const new({
    required this.preview,
    required this.controls,
    required this.card,
    super.key,
    this.onLeave,
  });

  final Widget preview;
  final Widget controls;
  final Widget card;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      final gap = wide ? 24.0 : 16.0;
      return Semantics(
        container: true,
        label: 'Waiting room',
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [entryCream, entryCream, entryMauve],
              stops: [0, 0.42, 1],
            ),
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: wide
                        ? const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 40,
                          )
                        : const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: wide ? 16 : 12,
                      children: [
                        if (onLeave != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: entrySlate,
                                minimumSize: const Size(44, 44),
                                iconSize: 18,
                              ),
                              tooltip: 'Leave',
                              onPressed: onLeave,
                              icon: const Icon(Icons.chevron_left),
                            ),
                          ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: gap,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: wide ? 420 : double.infinity,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: gap,
                                  children: [
                                    SizedBox(
                                      width: 234,
                                      height: 280.8,
                                      child: preview,
                                    ),
                                    card,
                                  ],
                                ),
                              ),
                              controls,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
