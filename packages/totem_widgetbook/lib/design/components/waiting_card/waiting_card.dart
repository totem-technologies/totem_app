import 'package:flutter/widgets.dart';

import '../../tokens/tokens.dart';

/// Figma waiting-for-approval card (3796:9181): a white slab under the
/// preview. Title, a short wait line, then whatever [action] the parent
/// passes — usually the secondary Button.
///
/// Figma frame is 366 × 214, radius 25, 20px vertical / 10px horizontal
/// inset. The action is a slot so the parent can pass a Button, or
/// nothing, without this card knowing.
class WaitingCard extends StatelessWidget {
  const WaitingCard({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;

  /// The wait line. Plain [Text] or [Text.rich] — it picks up Body 1, centered.
  final Widget body;

  /// Slot for the action. Pass a [block] Button — it fills this
  /// column, which already tracks the card. No fixed pixel width.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;
    final action = this.action;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 366),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: TotemColors.coreWhite,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TotemText.h2.copyWith(color: ink),
            ),
            DefaultTextStyle(
              style: TotemText.body1.copyWith(color: ink),
              textAlign: TextAlign.center,
              child: body,
            ),
            // Stretch with the slab. The card is already `width: 100%`
            // up to 366; a block Button grows with that, keeps its
            // own min width and 20px inset, and stays centred.
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 10), child: action),
          ],
        ),
      ),
    );
  }
}
