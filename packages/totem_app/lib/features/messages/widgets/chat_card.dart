import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

class ChatCard extends StatelessWidget {
  const ChatCard({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.avatarSeed,
    this.unreadCount = 0,
    this.isOwnLastMessage = false,
    this.onTap,
  });

  final String name;
  final String lastMessage;
  final DateTime timestamp;
  final String? avatarSeed;
  final int unreadCount;
  final bool isOwnLastMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final timestampLabel = timeago.format(timestamp, allowFromNow: true);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            UserAvatar.custom(seed: avatarSeed, radius: 22, borderWidth: 0),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textHeading,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        timestampLabel,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? AppTheme.messagePurple
                              : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? AppTheme.textHeading
                                : isOwnLastMessage
                                ? AppTheme.textMuted
                                : AppTheme.messageReceivedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppTheme.messagePurple,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
