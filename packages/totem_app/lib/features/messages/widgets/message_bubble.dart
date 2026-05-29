import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.timestamp,
    required this.isOwn,
  });

  final String text;
  final String timestamp;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isOwn ? 0.80 : 0.75),
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14,
            vertical: 4.5,
          ),
          decoration: BoxDecoration(
            color: isOwn ? const Color(0xFFEDEBF5) : const Color(0xFFFAFAF7),
            border: isOwn
                ? null
                : Border.all(color: const Color(0xFFE8E5E0), width: 1),
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
                        ? const Color(0xFF3B2E5C)
                        : const Color(0xFF1F293B),
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Text(
                timestamp,
                style: TextStyle(
                  color: isOwn
                      ? const Color(0xFF8C7AA8)
                      : const Color(0xFF8C8A82),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
