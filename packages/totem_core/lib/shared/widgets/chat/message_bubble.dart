import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';

/// Sent / received bubble used by DMs and in-call session chat.
///
/// Own messages use the mauve fill + tail on the trailing corner; received
/// messages use a bordered cream card with the tail on the leading corner.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.text,
    required this.timestamp,
    required this.isOwn,
    super.key,
  });

  final String text;
  final String timestamp;
  final bool isOwn;

  static const double _ownMaxWidthFactor = 0.84;
  static const double _receivedMaxWidthFactor = 0.86;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxBubbleWidth =
              constraints.maxWidth *
              (isOwn ? _ownMaxWidthFactor : _receivedMaxWidthFactor);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isOwn ? AppTheme.messagePurpleBg : AppTheme.surfaceCard,
                border: isOwn
                    ? null
                    : Border.all(color: AppTheme.divider, width: 1),
                borderRadius: isOwn
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4.5),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(5),
                      ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: 14,
                  vertical: isOwn ? 4.5 : 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text,
                      textWidthBasis: TextWidthBasis.longestLine,
                      style: TextStyle(
                        color: isOwn
                            ? AppTheme.messagePurpleText
                            : AppTheme.slate,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: isOwn ? 11 : 5),
                    Text(
                      timestamp,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: isOwn
                            ? AppTheme.messagePurple
                            : AppTheme.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
