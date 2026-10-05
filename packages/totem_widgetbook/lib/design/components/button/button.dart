import 'package:material_ui/material_ui.dart';

import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

/// Primary is the filled call to action. Secondary is its outlined twin.
/// Text has no chrome — a quiet action under a primary.
enum ButtonVariant { primary, secondary, text }

/// Compact is the dense row: Admit / Decline / Join in a card.
enum ButtonSize { regular, compact }

/// Totem's pill button.
///
/// Primary is Figma "Button / Primary" (3734:10292): mauve pill, white
/// SemiBold 16, 52px tall. Secondary keeps that geometry with a mauve
/// outline. Text drops the pill.
///
/// Width is flex, not a Figma frame. Regular pills sit on a 140 min
/// and grow when [block] is set, so the same control works on phone
/// and desktop. A null `onPressed` disables it, which reads as
/// "waiting, not broken". For a link inside a sentence, use
/// [Button.inlineSpan].
class Button extends StatelessWidget {
  const Button({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.regular,
    this.block = false,
    this.semanticLabel,
  });

  /// Label, usually a [Text]. Styled by the variant.
  final Widget child;

  /// Null disables the button. Primary reads as "waiting, not broken".
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;

  /// Fill the parent. Same pill on phone and desktop — the parent
  /// decides the width, this just grows. A short label still sits on
  /// [_regularMinWidth] so it does not collapse into a stub.
  final bool block;
  final String? semanticLabel;

  /// Floor for a regular pill. Compact and text hug the label instead.
  static const _regularMinWidth = 140.0;

  /// A link that flows inside a sentence. Text variant only.
  /// Pass the sentence's [style] so the link keeps its size.
  static InlineSpan inlineSpan({
    required String text,
    required TextStyle style,
    VoidCallback? onPressed,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Pressable(
        onTap: onPressed,
        focusColor: TotemColors.coreSlate,
        focusRadius: BorderRadius.circular(Radii.sm),
        builder: (context, states) => Text(
          text,
          style: style.copyWith(
            color: TotemColors.coreMauve,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: TotemColors.coreMauve,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = size == ButtonSize.compact;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final secondaryInk = highContrast
        ? TotemColors.coreSlate
        : TotemColors.coreMauve;
    final type = compact ? TotemText.buttonSmall : TotemText.button;

    // Regular is a 52-tall pill with 20px inset. Compact is the dense
    // row. Text drops the chrome. Width is never a Figma frame — hug
    // the label, keep a floor, grow when [block] so phone and desktop
    // share one control.
    final double minHeight;
    final double minWidth;
    final double padding;
    switch ((variant, compact)) {
      case (ButtonVariant.text, false):
        minHeight = 44;
        minWidth = 0;
        padding = Spacing.s8;
      case (ButtonVariant.text, true):
        minHeight = 32;
        minWidth = 0;
        padding = 0;
      case (_, false):
        minHeight = 52;
        minWidth = _regularMinWidth;
        padding = Spacing.s20;
      case (_, true):
        minHeight = 36;
        minWidth = 0;
        padding = Spacing.s12;
    }

    return Pressable(
      onTap: onPressed,
      pressedScale: 0.97,
      focusColor: TotemColors.coreSlate,
      focusRadius: BorderRadius.circular(Radii.full),
      semanticLabel: semanticLabel,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final hovered = states.contains(WidgetState.hovered);

        Color background = Colors.transparent;
        Color foreground;
        Border? border;
        var underline = false;

        switch (variant) {
          case ButtonVariant.primary:
            background = disabled
                ? mix(TotemColors.coreMauve, 0.16, TotemColors.coreWhite)
                : hovered
                ? mix(TotemColors.coreSlate, 0.12, TotemColors.coreMauve)
                : TotemColors.coreMauve;
            foreground = disabled
                ? mix(TotemColors.coreMauve, 0.85, TotemColors.coreSlate)
                : TotemColors.coreWhite;
          case ButtonVariant.secondary:
            if (hovered) background = fade(TotemColors.coreMauve, 0.08);
            foreground = disabled
                ? mix(TotemColors.coreMauve, 0.45, TotemColors.coreWhite)
                : secondaryInk;
            border = Border.all(
              width: 1.5,
              color: disabled
                  ? fade(TotemColors.coreMauve, 0.35)
                  : secondaryInk,
            );
          case ButtonVariant.text:
            foreground = disabled
                ? TotemTheme.of(context).textSecondary
                : TotemColors.coreMauve;
            underline = hovered;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: block ? double.infinity : null,
          constraints: BoxConstraints(minHeight: minHeight, minWidth: minWidth),
          padding: EdgeInsets.symmetric(horizontal: padding),
          decoration: BoxDecoration(
            color: background,
            border: border,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: DefaultTextStyle(
                  style: type.copyWith(
                    color: foreground,
                    decoration: underline ? TextDecoration.underline : null,
                    decorationColor: foreground,
                  ),
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: IconTheme(
                    data: IconThemeData(color: foreground, size: type.fontSize),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
