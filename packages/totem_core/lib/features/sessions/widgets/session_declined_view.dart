import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// The declined entry state. The offer is supplied by the caller (or omitted);
/// selecting it and signing up are separate actions owned by the host.
class SessionDeclinedView extends StatelessWidget {
  const SessionDeclinedView({
    required this.message,
    required this.actionLabel,
    super.key,
    this.offer,
    this.offerDescription,
    this.onOffer,
    this.signedUp = false,
    this.onSignUp,
    this.onBackToSpace,
    this.backActionLabel = 'Return to the Space',
  });

  final String message;
  final Widget? offer;
  final String? offerDescription;
  final VoidCallback? onOffer;
  final String actionLabel;
  final bool signedUp;
  final VoidCallback? onSignUp;
  final VoidCallback? onBackToSpace;
  final String backActionLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 640;
      final offer = this.offer;
      final theme = Theme.of(context);
      return Semantics(
        container: true,
        label: 'Session unavailable',
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: isWide ? 48 : 20,
                  vertical: isWide ? 48 : 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 20,
                      children: [
                        Center(
                          child: Container(
                            width: isWide ? 80 : 64,
                            height: isWide ? 80 : 64,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppTheme.mauve,
                              shape: BoxShape.circle,
                            ),
                            child: TotemIcon(
                              TotemIcons.x,
                              color: AppTheme.white,
                              size: isWide ? 38 : 30,
                            ),
                          ),
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            'Session unavailable',
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Text(
                          message,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        if (offer != null)
                          _Offer(
                            offer: offer,
                            description: offerDescription,
                            onPressed: onOffer,
                          ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (offer != null)
                              FilledButton(
                                onPressed: signedUp ? null : onSignUp,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.paleGreen,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(0, 48),
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                        horizontal: 24,
                                      ),
                                ),
                                child: Text(
                                  signedUp ? "You're signed up" : actionLabel,
                                ),
                              ),
                            TextButton(
                              onPressed: onBackToSpace,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    theme.textTheme.bodyLarge?.color,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 24,
                                ),
                              ),
                              child: Text(backActionLabel),
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

class _Offer extends StatelessWidget {
  const _Offer({
    required this.offer,
    required this.description,
    required this.onPressed,
  });

  final Widget offer;
  final String? description;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return offer;

    return Semantics(
      button: true,
      label: description,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onPressed, child: offer),
      ),
    );
  }
}
