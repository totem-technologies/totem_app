import 'package:flutter/material.dart';
import 'package:totem_core/core/config/theme.dart';

import '../widgets/day_separator.dart';
import '../widgets/message_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

class ThreadScreen extends StatelessWidget {
  const ThreadScreen({super.key});

  static const _messages = [
    _MockMessage(
      text: 'That really means a lot to me, thank you for sharing',
      timestamp: '10:34 AM',
      isOwn: false,
    ),
    _MockMessage(
      text:
          "I hear you. I've been there so many times. You're not alone, I promise.",
      timestamp: '10:33 AM',
      isOwn: false,
    ),
    _MockMessage(
      text:
          "Honestly, today's been tough. But talking helps. It's nice not to feel alone in it.",
      timestamp: '10:31 AM',
      isOwn: true,
    ),
    _MockMessage(
      text:
          'Totally. Some days are harder than others. How are you doing today?',
      timestamp: '10:28 AM',
      isOwn: false,
    ),
    _MockMessage(
      text:
          "Hi Vanessa! Thanks for reaching out. It's nice to connect with someone who gets it.",
      timestamp: '10:25 AM',
      isOwn: true,
    ),
    _MockMessage(
      text: 'Hey! I saw your profile and I think we have a lot in common.',
      timestamp: '10:23 AM',
      isOwn: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _ThreadHeader(
              name: 'Vanessa',
              avatarColor: Color(0xFFB6E07A),
              avatarSecondary: Color(0xFFE7E36A),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const DaySeparator(label: 'Today');
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MessageBubble(
                      text: _messages[index].text,
                      timestamp: _messages[index].timestamp,
                      isOwn: _messages[index].isOwn,
                    ),
                  );
                },
              ),
            ),
            const MessageInputBar(),
          ],
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.name,
    required this.avatarColor,
    this.avatarSecondary,
  });

  final String name;
  final Color avatarColor;
  final Color? avatarSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFFFAFAF7),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      child: Row(
        children: [
          MessageAvatar(
            color: avatarColor,
            secondary: avatarSecondary,
            size: 46,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              name,
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

class _MockMessage {
  const _MockMessage({
    required this.text,
    required this.timestamp,
    required this.isOwn,
  });

  final String text;
  final String timestamp;
  final bool isOwn;
}
