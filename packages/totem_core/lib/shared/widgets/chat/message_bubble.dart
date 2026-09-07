import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isOwn ? 0.80 : 0.75),
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14,
            vertical: 4.5,
          ),
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
                    bottomRight: Radius.circular(4),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  text,
                  style: TextStyle(
                    color: isOwn
                        ? AppTheme.messagePurpleText
                        : AppTheme.textHeading,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Text(
                timestamp,
                style: TextStyle(
                  color: isOwn ? AppTheme.messagePurple : AppTheme.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
