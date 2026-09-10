import 'package:flutter/foundation.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/models/message.dart';

@immutable
class ConversationPage {
  const ConversationPage({
    required this.items,
    required this.totalUnreadCount,
    this.nextCursor,
  });

  final List<Conversation> items;
  final String? nextCursor;
  final int totalUnreadCount;
}

@immutable
class MessagePage {
  const MessagePage({
    required this.items,
    required this.hasMore,
    this.nextBefore,
    this.nextAfter,
  });

  final List<Message> items;
  final String? nextBefore;
  final String? nextAfter;
  final bool hasMore;
}
