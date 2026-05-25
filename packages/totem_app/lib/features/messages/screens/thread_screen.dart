import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/providers/thread_provider.dart';

import '../widgets/day_separator.dart';
import '../widgets/message_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

class ThreadScreen extends ConsumerWidget {
  const ThreadScreen({
    super.key,
    required this.conversationId,
    required this.conversation,
  });

  final String conversationId;
  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMessages = ref.watch(threadNotifierProvider(conversationId));

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ThreadHeader(conversation: conversation),
            Expanded(
              child: asyncMessages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text('Could not load messages.'),
                ),
                data: (messages) => _MessageList(messages: messages),
              ),
            ),
            MessageInputBar(
              onSend: (text) => ref
                  .read(threadNotifierProvider(conversationId).notifier)
                  .send(text),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const DaySeparator(label: 'Today');
        }
        final msg = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MessageBubble(
            text: msg.text,
            timestamp: DateFormat.jm().format(msg.sentAt),
            isOwn: msg.isOwn,
          ),
        );
      },
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final peer = conversation.peer;
    final avatarColor = MessageAvatar.colorFromSeed(peer.profileAvatarSeed);

    return Container(
      height: 56,
      color: const Color(0xFFFAFAF7),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Color(0xFF1F293B),
            ),
          ),
          const SizedBox(width: 12),
          MessageAvatar(color: avatarColor, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              peer.name ?? 'Unknown',
              style: const TextStyle(
                color: Color(0xFF1F293B),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            '⋮',
            style: TextStyle(
              color: Color(0xFF8C8A82),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
