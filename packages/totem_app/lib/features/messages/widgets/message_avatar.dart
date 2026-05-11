import 'package:flutter/material.dart';

class MessageAvatar extends StatelessWidget {
  const MessageAvatar({
    super.key,
    required this.color,
    this.secondary,
    this.size = 44,
  });

  final Color color;
  final Color? secondary;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: secondary != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, secondary!],
              )
            : null,
        color: secondary == null ? color : null,
      ),
    );
  }
}
