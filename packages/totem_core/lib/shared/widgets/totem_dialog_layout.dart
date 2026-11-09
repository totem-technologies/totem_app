import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Shared layout for Totem's centered dialogs: optional icon, title, body and
/// a stacked column of full-width actions.
///
/// Holds no state or pop logic, so dialogs such as ConfirmationDialog and
/// UpdateAvailableDialog keep their own behavior while sharing the design.
class TotemDialogLayout extends StatelessWidget {
  const TotemDialogLayout({
    required this.title,
    required this.actions,
    this.icon,
    this.body = const [],
    this.scrollable = false,
    this.bodyMaxHeight,
    super.key,
  });

  /// Widget shown above the title, already sized by the caller.
  final Widget? icon;
  final String title;

  /// Widgets shown under the title.
  final List<Widget> body;

  /// Buttons stacked under the body, primary action first.
  final List<Widget> actions;

  /// Whether the whole dialog content scrolls when the viewport is too short.
  final bool scrollable;

  /// When set, the icon, title and body scroll within this height while the
  /// actions stay visible.
  final double? bodyMaxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ViewportResolver(
      builder: (context, viewportKind) {
        final contentPadding = switch (viewportKind) {
          ViewportKind.mediumSmall ||
          ViewportKind.mediumPlus => const EdgeInsetsDirectional.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          _ => const EdgeInsetsDirectional.symmetric(
            horizontal: 24,
            vertical: 28,
          ),
        };

        Widget header = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            ?icon,
            Semantics(
              header: true,
              namesRoute: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style:
                    (theme.dialogTheme.titleTextStyle ??
                            theme.textTheme.titleLarge)
                        ?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                        ),
              ),
            ),
            ...body,
          ],
        );
        if (bodyMaxHeight case final maxHeight?) {
          header = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(child: header),
          );
        }

        return AlertDialog(
          scrollable: scrollable,
          constraints: const BoxConstraints(maxWidth: 480),
          contentPadding: contentPadding,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              header,
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: actions,
              ),
            ],
          ),
        );
      },
    );
  }
}
