import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

/// The declined entry state. The offer is supplied by the caller (or omitted);
/// selecting it and signing up are separate actions owned by the host.
class SessionDeclinedView extends StatelessWidget {
  const new({
    required this.message,
    required this.actionLabel,
    super.key,
    this.offer,
    this.offerDescription,
    this.onOffer,
    this.signedUp = false,
    this.onSignUp,
    this.onBackToSpace,
  });

  final String message;
  final Widget? offer;
  final String? offerDescription;
  final VoidCallback? onOffer;
  final String actionLabel;
  final bool signedUp;
  final VoidCallback? onSignUp;
  final VoidCallback? onBackToSpace;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      final offer = this.offer;
      return Semantics(
        container: true,
        label: 'Session unavailable',
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        const Text(
                          'SESSION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: entryMauve,
                          ),
                        ),
                        Semantics(
                          header: true,
                          child: const Text(
                            "We're sorry, this session is no longer available for admission, but we'd love to see you soon.",
                            style: entryTitle,
                          ),
                        ),
                        Text(message, style: entryMuted),
                        if (offer != null && onOffer == null) offer,
                        if (offer != null && onOffer != null)
                          InkWell(
                            onTap: onOffer,
                            child: Semantics(
                              button: true,
                              label: offerDescription,
                              child: offer,
                            ),
                          ),
                        Column(
                          spacing: 8,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (offer != null && wide)
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 240,
                                  ),
                                  child: SessionEntryAction(
                                    label: signedUp
                                        ? "You're signed up"
                                        : actionLabel,
                                    onPressed: signedUp ? null : onSignUp,
                                  ),
                                ),
                              ),
                            if (offer != null && !wide)
                              SessionEntryAction(
                                label: signedUp
                                    ? "You're signed up"
                                    : actionLabel,
                                onPressed: signedUp ? null : onSignUp,
                                expand: true,
                              ),
                            Center(
                              child: SessionEntryAction(
                                label: 'Return to the Space',
                                onPressed: onBackToSpace,
                                quiet: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
