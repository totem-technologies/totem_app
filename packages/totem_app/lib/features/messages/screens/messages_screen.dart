import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/config/theme.dart';

import '../widgets/chat_card.dart';
import '../widgets/message_search_field.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  static const List<_MockChat> _mockChats = [
    _MockChat(
      name: 'Vanessa',
      lastMessage: 'That really means a lot to me, thank you...',
      timestamp: '2m ago',
      unreadCount: 2,
      avatarColor: Color(0xFFB6E07A),
      avatarSecondary: Color(0xFFE7E36A),
    ),
    _MockChat(
      name: 'Marcus',
      lastMessage: "You: I'll check in with you tomorrow",
      timestamp: '1h ago',
      avatarColor: Color(0xFF9BC0DD),
    ),
    _MockChat(
      name: 'Sarah',
      lastMessage: 'You: Take care of yourself this weekend',
      timestamp: 'Yesterday',
      avatarColor: Color(0xFFF5E3E8),
    ),
    _MockChat(
      name: 'Jordan',
      lastMessage: '3 months sober today! Wanted to share...',
      timestamp: 'Mar 21',
      avatarColor: Color(0xFFE85A2B),
      avatarSecondary: Color(0xFFFFC857),
    ),
    _MockChat(
      name: 'Alex',
      lastMessage: 'Let me know if you ever want to talk again',
      timestamp: 'Mar 18',
      avatarColor: Color(0xFF8B5CF6),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFFFAFAF7),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                          color: AppTheme.mauve,
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: MessageSearchField(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              sliver: SliverList.separated(
                itemCount: _mockChats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final chat = _mockChats[index];
                  return ChatCard(
                    name: chat.name,
                    lastMessage: chat.lastMessage,
                    timestamp: chat.timestamp,
                    unreadCount: chat.unreadCount,
                    avatarColor: chat.avatarColor,
                    avatarSecondary: chat.avatarSecondary,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockChat {
  const _MockChat({
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.avatarColor,
    this.unreadCount = 0,
    this.avatarSecondary,
  });

  final String name;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final Color avatarColor;
  final Color? avatarSecondary;
}
