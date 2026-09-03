import 'package:flutter/material.dart';
import 'package:totem_core/core/config/theme.dart';

class MessageSearchField extends StatelessWidget {
  const MessageSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: AppTheme.messageSearchBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Search messages',
        style: TextStyle(
          color: AppTheme.messageSearchText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
