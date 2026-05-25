import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/shared/router.dart';

import '../widgets/chat_card.dart';
import '../widgets/message_search_field.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncConversations = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: const Color(0xFFFAFAF7),
            padding: EdgeInsetsDirectional.only(
              top: MediaQuery.of(context).padding.top,
            ),
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Messages',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1F293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 21,
                      ),
                    ),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8C7AA8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 80,
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 18),
              child: MessageSearchField(),
            ),
          ),
          Expanded(
            child: asyncConversations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Could not load messages.'),
              ),
              data: (conversations) => _ConversationList(
                conversations: conversations,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.conversations});

  final List<Conversation> conversations;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final lastMsg = conv.lastMessage;
        final preview = lastMsg == null
            ? ''
            : lastMsg.isOwn
            ? 'You: ${lastMsg.text}'
            : lastMsg.text;

        return ChatCard(
          name: conv.peer.name ?? 'Unknown',
          lastMessage: preview,
          timestamp: conv.updatedAt,
          avatarSeed: conv.peer.profileAvatarSeed,
          unreadCount: conv.unreadCount,
          isOwnLastMessage: lastMsg?.isOwn ?? false,
          onTap: () => context.push(
            RouteNames.messageThread(conv.id),
            extra: conv,
          ),
        );
      },
    );
  }
}
