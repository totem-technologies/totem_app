part of 'auth_flow.dart';

/// iOS system alert for notification permission. The Figma frame
/// (2428:1418) only carries the dim; the alert itself is drawn to the
/// standard iOS metrics.
class _IosPrompt extends StatelessWidget {
  const _IosPrompt({required this.onAnswer});

  final ValueChanged<bool>? onAnswer;

  // Unmapped: iOS system alert colors.
  static const _surface = Color(0xF0F2F2F2);
  static const _blue = Color(0xFF007AFF);
  static const _rule = Color(0x4D3C3C43);

  @override
  Widget build(BuildContext context) {
    final action = TotemText.raw(size: 17, color: _blue);

    Widget button(String label, bool allow, {bool bold = false}) => Expanded(
      child: Pressable(
        onTap: onAnswer == null ? null : () => onAnswer!(allow),
        focusColor: _blue,
        builder: (context, states) => Container(
          height: 44,
          alignment: Alignment.center,
          color: states.contains(WidgetState.pressed)
              ? const Color(0x14000000)
              : null,
          child: Text(
            label,
            style: bold ? action.copyWith(fontWeight: FontWeight.w600) : action,
          ),
        ),
      ),
    );

    return ColoredBox(
      color: _scrim,
      child: Center(
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          child: Container(
            width: 270,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 19, 16, 19),
                  child: Column(
                    spacing: 2,
                    children: [
                      Text(
                        '“Totem” Would Like to Send You Notifications',
                        textAlign: TextAlign.center,
                        style: TotemText.raw(
                          size: 17,
                          weight: FontWeight.w600,
                          height: 1.3,
                          color: const Color(0xFF000000),
                        ),
                      ),
                      Text(
                        'Notifications may include alerts, sounds and icon '
                        'badges. These can be configured in Settings.',
                        textAlign: TextAlign.center,
                        style: TotemText.raw(
                          size: 13,
                          height: 1.3,
                          color: const Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 0.5, thickness: 0.5, color: _rule),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      button('Don’t Allow', false),
                      const VerticalDivider(
                        width: 0.5,
                        thickness: 0.5,
                        color: _rule,
                      ),
                      button('Allow', true, bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma "Permission Android" (2429:10138).
class _AndroidPrompt extends StatelessWidget {
  const _AndroidPrompt({required this.onAnswer});

  final ValueChanged<bool>? onAnswer;

  // Figma .Android/Light/* styles.
  static const _text = Color(0xFF212121);
  static const _primary = Color(0xFF0072F0);
  static const _stroke = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    final body = TotemText.raw(size: 16, height: 22 / 16, color: _text);

    Widget button(String label, bool allow) => Pressable(
      onTap: onAnswer == null ? null : () => onAnswer!(allow),
      focusColor: _primary,
      builder: (context, states) => Container(
        width: 280,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: states.contains(WidgetState.pressed)
              ? const Color(0x0F000000)
              : null,
          border: const Border(top: BorderSide(color: _stroke)),
        ),
        child: Text(
          label,
          style: TotemText.raw(
            size: 12,
            weight: FontWeight.w500,
            height: 16 / 12,
            color: _primary,
          ),
        ),
      ),
    );

    return ColoredBox(
      color: _scrim,
      child: Center(
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          child: Container(
            padding: const EdgeInsets.only(top: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: TotemColors.coreWhite,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  offset: Offset(0, 4),
                  blurRadius: 17,
                  color: Color(0x40000000),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                SvgPicture.asset(
                  '$_assets/android-bell.svg',
                  width: 18,
                  height: 18,
                ),
                SizedBox(
                  width: 232,
                  child: Text.rich(
                    TextSpan(
                      style: body,
                      children: [
                        const TextSpan(text: 'Allow '),
                        TextSpan(
                          text: 'Totem',
                          style: body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' to send you notifications?'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Column(
                  children: [button('Allow', true), button('Deny', false)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
