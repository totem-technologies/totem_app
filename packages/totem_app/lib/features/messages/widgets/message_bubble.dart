import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/models/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.timestamp,
    required this.isOwn,
    this.status = MessageStatus.sent,
    this.onRetry,
  });

  final String text;
  final String timestamp;
  final bool isOwn;
  final MessageStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = status == MessageStatus.failed;
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isOwn
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.sizeOf(context).width * (isOwn ? 0.80 : 0.75),
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
                    status == MessageStatus.pending ? 'Sending…' : timestamp,
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
          if (failed)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Not sent. Retry'),
            ),
        ],
      ),
    );
  }
}
