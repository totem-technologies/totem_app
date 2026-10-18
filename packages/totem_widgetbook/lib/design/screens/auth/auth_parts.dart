part of 'auth_flow.dart';

// Unmapped: auth frames use these greys and inks. None are Totem variables.
const _fieldFill = Color(0xFFD9D9D9);
const _placeholder = Color(0xFFA2A2A2);
const _ink = Color(0xFF1F2937);
const _body = Color(0xFF1E1E1E);
const _hint = Color(0xFF717171);
const _fine = Color(0xFF6B7280);

/// Violet links on Verify Code and Guidelines. The Get Started links are
/// mauve; Figma uses both.
const _violet = Color(0xFF8B5CF6);

/// Dimmed page behind a sheet or system dialog.
const _scrim = Color(0x40000000);

/// White card in the middle of the cream page, used by every step after
/// the welcome slides. Scrolls when the card is taller than the screen.
class _CardPage extends StatelessWidget {
  const _CardPage({required this.children, this.spacing = 16});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.s20,
          _statusBarHeight + Spacing.s12,
          Spacing.s20,
          Spacing.s32,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - _statusBarHeight - 44,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 349),
              child: Container(
                padding: const EdgeInsets.all(Spacing.s20),
                decoration: BoxDecoration(
                  color: TotemColors.coreWhite,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: Shadows.elevation1,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma "button / primary" (21:6): 56 tall, 20 radius, 21px label. Older
/// than the catalog's pill [Button]; the auth frames still use it.
class _AuthButton extends StatelessWidget {
  const _AuthButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.lg);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      focusColor: TotemColors.coreSlate,
      focusRadius: radius,
      builder: (context, states) => Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: states.contains(WidgetState.disabled)
              ? fade(TotemColors.coreMauve, 0.5)
              : states.contains(WidgetState.hovered)
              ? mix(TotemColors.coreSlate, 0.12, TotemColors.coreMauve)
              : TotemColors.coreMauve,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              offset: Offset(0, 2),
              blurRadius: 4,
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Text(
          label,
          style: TotemText.raw(
            size: 21,
            weight: FontWeight.w600,
            color: TotemColors.coreWhite,
          ),
        ),
      ),
    );
  }
}

/// Grey 53px field showing a value, or its placeholder when empty.
class _Field extends StatelessWidget {
  const _Field({
    required this.value,
    required this.placeholder,
    this.onTap,
    this.error = false,
  });

  final String value;
  final String placeholder;

  /// Pickers open from the field instead of typing.
  final VoidCallback? onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.lg);
    final empty = value.isEmpty;

    Widget field(Set<WidgetState> states) => Container(
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: radius,
        border: error
            ? Border.all(color: TotemColors.semanticError, width: 2)
            : null,
      ),
      child: Text(
        empty ? placeholder : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TotemText.raw(
          size: 14,
          weight: FontWeight.w500,
          color: empty ? _placeholder : TotemColors.coreSlate,
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(
        textField: true,
        label: placeholder,
        value: value,
        child: ExcludeSemantics(child: field(const {})),
      );
    }
    return Pressable(
      onTap: onTap,
      focusColor: TotemColors.coreMauve,
      focusRadius: radius,
      semanticLabel: empty ? placeholder : value,
      excludeChildSemantics: true,
      builder: (context, states) => field(states),
    );
  }
}

/// Label, field and an info line under it (Figma "Frame 20", 196:1725).
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.hint,
    this.onTap,
  });

  final String label;
  final String value;
  final String placeholder;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 5,
      children: [
        Text(
          label,
          style: TotemText.raw(
            size: 14,
            weight: FontWeight.w500,
            color: const Color(0xFF000000),
          ),
        ),
        _Field(value: value, placeholder: placeholder, onTap: onTap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5,
          children: [
            // The glyph's stroke overhangs its 15px slot.
            SizedBox.square(
              dimension: 15,
              child: OverflowBox(
                maxWidth: 16.1111,
                maxHeight: 16.1111,
                child: SvgPicture.asset(
                  '$_assets/icon-info.svg',
                  width: 16.1111,
                  height: 16.1111,
                ),
              ),
            ),
            Expanded(
              child: Text(
                hint,
                style: TotemText.raw(
                  size: 10,
                  weight: FontWeight.w500,
                  color: _hint,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Outlined option with a radio on the right (Figma "selector", 73:7463).
/// Used single-choice in the referral sheet and multi-choice for
/// communities.
class _Selector extends StatelessWidget {
  const _Selector({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.lg);

    return Pressable(
      onTap: onTap,
      focusColor: TotemColors.coreMauve,
      focusRadius: radius,
      selected: selected,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? fade(TotemColors.coreMauve, 0.06)
              : TotemColors.coreWhite,
          border: Border.all(
            color: selected ? TotemColors.coreMauve : _fieldFill,
            width: 2,
          ),
          borderRadius: radius,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TotemText.raw(
                  size: 14,
                  weight: FontWeight.w500,
                  color: selected ? TotemColors.coreMauve : _placeholder,
                ),
              ),
            ),
            SvgPicture.asset(
              selected ? '$_assets/radio-on.svg' : '$_assets/radio-off.svg',
              width: 25,
              height: 25,
            ),
          ],
        ),
      ),
    );
  }
}

/// Step title and the line under it.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.subtitle,
    this.subtitleSize = 14,
  });

  final String title;
  final String subtitle;
  final double subtitleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TotemText.h2.copyWith(color: const Color(0xFF000000)),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TotemText.raw(size: subtitleSize, color: _body),
        ),
      ],
    );
  }
}
