part of 'auth_flow.dart';

/// Dimmed page with a white sheet at the bottom. Tapping the dim closes
/// it.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const ColoredBox(color: _scrim),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              decoration: const BoxDecoration(
                color: TotemColors.coreWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: Shadows.elevation1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: Spacing.s20,
                children: [
                  Container(
                    width: 80,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF232327),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 318),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Figma 2427:939: bigger avatar with a shuffle badge, Tie Dye / Image
/// switch, Save.
class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet({
    required this.style,
    required this.onStyle,
    required this.onSave,
  });

  final AvatarStyle style;
  final ValueChanged<AvatarStyle>? onStyle;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.s20,
      children: [
        _Avatar(
          style: style,
          // The shuffle disc carries room for a shadow Flutter does not
          // draw; this offset puts the 41px disc where Figma has it.
          badge: Positioned(
            left: 51,
            top: 53,
            child: SvgPicture.asset(
              '$_assets/badge-shuffle.svg',
              width: 57,
              height: 57,
            ),
          ),
          onTap: onStyle == null
              ? null
              : () => onStyle!(
                  style == AvatarStyle.tieDye
                      ? AvatarStyle.image
                      : AvatarStyle.tieDye,
                ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: TotemColors.coreCream,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                for (final option in AvatarStyle.values)
                  Pressable(
                    onTap: onStyle == null ? null : () => onStyle!(option),
                    focusColor: TotemColors.coreMauve,
                    focusRadius: BorderRadius.circular(25),
                    selected: option == style,
                    builder: (context, states) => Container(
                      width: 120,
                      height: 33,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: option == style ? _fieldFill : null,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        option.label,
                        style: TotemText.body2.copyWith(
                          color: TotemColors.coreSlate,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _AuthButton(label: 'Save', onTap: onSave),
      ],
    );
  }
}

/// Figma 2427:971: one answer to "How did you hear about us?".
class _ReferralSheet extends StatelessWidget {
  const _ReferralSheet({
    required this.selected,
    required this.onSelect,
    required this.onSave,
  });

  final Referral? selected;
  final ValueChanged<Referral>? onSelect;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.s20,
      children: [
        const _Heading(
          title: 'How did you hear about us?',
          subtitle:
              'This helps us understand how to reach more people like '
              'you.',
        ),
        Column(
          spacing: 5,
          children: [
            for (final option in Referral.values)
              _Selector(
                label: option.label,
                selected: option == selected,
                onTap: onSelect == null ? null : () => onSelect!(option),
              ),
          ],
        ),
        _AuthButton(label: 'Save', onTap: selected == null ? null : onSave),
      ],
    );
  }
}
