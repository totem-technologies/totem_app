import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/providers/thread_provider.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

import '../widgets/day_separator.dart';
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
    final asyncMessages = ref.watch(threadProvider(conversationId));

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Column(
        children: [
          _ThreadHeader(conversation: conversation),
          Expanded(
            child: asyncMessages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Could not load messages.')),
              data: (messages) => _MessageList(messages: messages),
            ),
          ),
          MessageInputBar(
            onSend: (text) =>
                ref.read(threadProvider(conversationId).notifier).send(text),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const DaySeparator(label: 'Today');
        }
        final msg = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 19),
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: const Color(0xFFFAFAF7),
      padding: EdgeInsetsDirectional.only(top: topPadding),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
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
              const SizedBox(width: 10),
              UserAvatar.custom(
                seed: peer.profileAvatarSeed,
                radius: 23,
                borderWidth: 0,
              ),
              const SizedBox(width: 15),
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
        ),
      ),
    );
  }
}
