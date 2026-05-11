import 'package:flutter/material.dart';
import 'package:totem_core/core/config/theme.dart';

class MessageInputBar extends StatelessWidget {
  const MessageInputBar({super.key, this.onSend});

  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAF7),
        border: Border(
          top: BorderSide(color: Color(0xFFE8E5E0)),
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 9),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 45,
                padding: const EdgeInsetsDirectional.only(start: 16),
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F0),
                  border: Border.all(color: const Color(0xFFE8E5E0)),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'Type a message...',
                  style: TextStyle(
                    color: Color(0xFF8C8A82),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(
                  color: AppTheme.mauve,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
